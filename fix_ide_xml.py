import xml.etree.ElementTree as ET

# Register namespace prefix if needed, though usually None is fine for CDT.
# We will just parse normally.
tree = ET.parse('.cproject')
root = tree.getroot()

# 1. Update builder
for builder in root.iter('builder'):
    builder.set('managedBuildOn', 'false')
    builder.set('autoBuildTarget', 'all')
    builder.set('incrementalBuildTarget', 'all')
    builder.set('cleanBuildTarget', 'clean')
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
            val2 = f"${{workspace_loc:/${{ProjName}}/{path}}}"
            if val2 not in existing:
                ET.SubElement(option, 'listOptionValue', {'builtIn': 'false', 'value': val2})

tree.write('.cproject', encoding='utf-8', xml_declaration=True)

# 3. Restore the Eclipse-specific processing instruction
with open('.cproject', 'r') as f:
    content = f.read()

if '<?fileVersion' not in content:
    # Insert right after the xml declaration
    parts = content.split('?>', 1)
    if len(parts) == 2:
        content = parts[0] + '?>\n<?fileVersion 4.0.0?>' + parts[1]

with open('.cproject', 'w') as f:
    f.write(content)

print("Properly updated .cproject using ElementTree with preserved fileVersion.")
