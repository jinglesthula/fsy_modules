const fs = require('fs');
const path = require('path');

// Input and output file paths
const inputFilePath = path.join(__dirname, 'linked_sessions.json');
const outputFilePath = path.join(__dirname, 'insertLinks.sql');

// Name for the created_by field
const createdBy = 'FSY-2883';

// Function to generate SQL statements
function generateSql(data) {
  let sqlStatements = '';

  data.forEach((array) => {
    const baseSession = array[0];

    for (let i = 1; i < array.length; i++) {
      const linkedSession = array[i];
      sqlStatements += `INSERT INTO fsy_session_link (base_session, linked_session, created_by) VALUES (${baseSession}, ${linkedSession}, '${createdBy}');\n`;
    }
  });

  return sqlStatements;
}

// Read and process the input JSON file
fs.readFile(inputFilePath, 'utf8', (err, data) => {
  if (err) {
    console.error(`Error reading input file: ${err}`);
    return;
  }

  try {
    const jsonData = JSON.parse(data);
    const sql = generateSql(jsonData);

    // Write the SQL output to a file
    fs.writeFile(outputFilePath, sql, 'utf8', (err) => {
      if (err) {
        console.error(`Error writing output file: ${err}`);
      } else {
        console.log(`SQL statements have been written to ${outputFilePath}`);
      }
    });
  } catch (parseError) {
    console.error(`Error parsing JSON data: ${parseError}`);
  }
});
