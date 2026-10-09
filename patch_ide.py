import xml.etree.ElementTree as ET

tree = ET.parse('.cproject')
root = tree.getroot()

# 1. Update builder to use custom Makefile
for builder in root.iter('builder'):
    builder.set('managedBuildOn', 'false')
    builder.set('autoBuildTarget', 'all')
    builder.set('incrementalBuildTarget', 'all')
    builder.set('cleanBuildTarget', 'clean')
    # Use the root directory as the build directory
    builder.set('buildPath', '${workspace_loc:/${ProjName}}')

# 2. Add Include paths
paths = [
    "Bootloader/Core/Inc",
    "Bootloader/Drivers/CMSIS/Include",
    "Bootloader/Drivers/CMSIS/Device",
    "Program/App/Inc",
    "Program/Core/Inc",
    "Program/Drivers/CMSIS/Include",
    "Program/Drivers/CMSIS/Device/ST/STM32G4xx/Include"
]

for option in root.iter('option'):
    if option.get('valueType') == 'includePath':
        existing = {v.get('value') for v in option.findall('listOptionValue')}
        for path in paths:
            val1 = f"../{path}"
            val2 = f"${{workspace_loc:/${{ProjName}}/{path}}}"
            if val1 not in existing and val2 not in existing:
                ET.SubElement(option, 'listOptionValue', {'builtIn': 'false', 'value': val2})

tree.write('.cproject', encoding='utf-8', xml_declaration=True)
print("Updated .cproject successfully.")
