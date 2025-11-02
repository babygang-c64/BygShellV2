import glob

file_pattern = '*.hlp'
file_list = glob.glob(file_pattern)

results = []

with open(".index.hlp", "wb") as hout:
    for file_path in file_list:
        if file_path.endswith('.index.hlp'):
            continue

        file_name = file_path[:-4]  # Supprime l'extension .hlp

        with open(file_path, 'r') as file:
            first_line = file.readline()
            first_line_processed = first_line[1:].strip()

        first_line_processed = first_line_processed[:30] if len(first_line_processed) > 30 else first_line_processed


        results.append([file_name, first_line_processed])
    hout.write(bytes([0]))
    hout.write(bytes([16]))
    hout.write(bytes([len(results)]))
    results.sort(key=lambda x: x[0])
    for item in results:
        for elem in item: 
            hout.write(bytes([len(elem)]))
            hout.write(elem.encode('ascii'))
print(results)
print(len(results))
