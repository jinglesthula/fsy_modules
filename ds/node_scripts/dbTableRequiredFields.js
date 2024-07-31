const fs = require('fs');
const readline = require('readline');

// Create readline interface for command line input
const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
});

// Function to parse the SQL schema file
function parseSQLSchema(sqlContent) {
    const fields = [];
    const primaryKeyRegex = /\[([^\]]+)\]\s+NUMERIC\s*\(\d+\)\s+NOT\s+NULL\s+IDENTITY/i;
    const fieldRegex = /\[([^\]]+)\]\s+([^\s]+(?:\s*\(\d+(?:,\d+)?\))?)\s+NOT\s+NULL(?:\s+DEFAULT\s+([^\s,]+))?/i;

    let inTableDefinition = false;

    // Split the SQL content into lines and process each line
    const lines = sqlContent.split('\n');
    for (let line of lines) {
        line = line.trim();
        // console.log({line})
        if (!inTableDefinition) {
            if (line.startsWith('CREATE TABLE')) {
                inTableDefinition = true;
            }
            continue;
        }

        if (line.startsWith(')')) {
            break; // End of table definition
        }

        // Remove comments
        const cleanedLine = line.split('--')[0].trim();
        // console.log({cleanedLine})
        let match;
        if ((match = primaryKeyRegex.exec(cleanedLine)) !== null) {
            // console.log('PK found!')
            continue; // Skip primary key fields
        }

        if ((match = fieldRegex.exec(cleanedLine)) !== null) {
            console.log(cleanedLine)
            const fieldName = match[1];
            const dataType = match[2];
            const defaultValue = match[3] || null;

            fields.push({ fieldName, dataType, default: defaultValue });
        }
    }

    return fields.filter(field => field.default === null).map(field => ({ fieldName: field.fieldName, dataType: field.dataType }));
}

// Prompt user for the file path
rl.question('Please enter the path to the .sql schema file: ', (filePath) => {
    // Read the file content
    fs.readFile(filePath, 'utf8', (err, data) => {
        if (err) {
            console.error(`Error reading file: ${err.message}`);
            rl.close();
            return;
        }

        // Parse the SQL schema
        const result = parseSQLSchema(data);

        // Output the result as JSON string
        console.log(JSON.stringify(result, null, 2));

        rl.close();
    });
});
