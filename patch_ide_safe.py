import re

with open('.cproject', 'r', encoding='utf-8') as f:
    xml = f.read()

# 1. Update builder to point to custom makefile and use 'all' target
# We will inject autoBuildTarget="all" incrementalBuildTarget="all" cleanBuildTarget="clean" buildPath="${workspace_loc:/str-miros-cpp-stm32g474}"
def update_builder(match):
    tag = match.group(0)
    # Remove old attributes if they exist
    for attr in ['autoBuildTarget', 'incrementalBuildTarget', 'cleanBuildTarget', 'buildPath']:
        tag = re.sub(rf'\s+{attr}="[^"]*"', '', tag)
    
    # Insert our custom attributes right after <builder
    additions = ' autoBuildTarget="all" incrementalBuildTarget="all" cleanBuildTarget="clean" buildPath="${workspace_loc:/str-miros-cpp-stm32g474}"'
    return tag.replace('<builder', '<builder' + additions)

xml = re.sub(r'<builder[^>]*>', update_builder, xml)

# 2. Add include paths
paths = [
    "Bootloader/Core/Inc",
    "Bootloader/Drivers/CMSIS/Include",
    "Bootloader/Drivers/CMSIS/Device",
    "Program/App/Inc",
    "Program/Core/Inc",
    "Program/Drivers/CMSIS/Include",
    "Program/Drivers/CMSIS/Device/ST/STM32G4xx/Include"
]

include_option_c = 'com.st.stm32cube.ide.mcu.gnu.managedbuild.tool.c.compiler.option.includepaths'
include_option_cpp = 'com.st.stm32cube.ide.mcu.gnu.managedbuild.tool.cpp.compiler.option.includepaths'

def inject_paths(match):
    block = match.group(0)
    injections = ""
    for p in paths:
        path_str = f"../{p}"
        if path_str not in block:
            injections += f'\n\t\t\t\t\t\t\t\t\t<listOptionValue builtIn="false" value="{path_str}"/>'
    
    # If the tag is self-closing, open it
    if block.endswith('/>'):
        block = block[:-2] + ">" + injections + "\n\t\t\t\t\t\t\t\t</option>"
    else:
        # insert right before the closing tag
        block = block.replace('</option>', injections + '\n\t\t\t\t\t\t\t\t</option>')
    return block

xml = re.sub(rf'<option [^>]*superClass="{include_option_c}"[^>]*>.*?(?:</option>|/>)', inject_paths, xml, flags=re.DOTALL)
xml = re.sub(rf'<option [^>]*superClass="{include_option_cpp}"[^>]*>.*?(?:</option>|/>)', inject_paths, xml, flags=re.DOTALL)

with open('.cproject', 'w', encoding='utf-8') as f:
    f.write(xml)

print("Safely updated .cproject")
