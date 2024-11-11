const fs = require('fs');
const csv = require('csv-parser');
const path = require('path');

// Paths for input CSV and output SQL file
const csvFilePath = path.join(__dirname, '2025 Travel Criteria.csv');
const sqlFilePath = path.join(__dirname, 'numbers.sql');

// Function to format value for SQL query
function formatValue(value) {
  if (value === 'x' || value == 'Linked') {
    return 'NULL';
  } else if (isNaN(value)) {
    return `'${value}'`; // Wrap string values in quotes
  } else {
    return value; // Numeric values don't need quotes
  }
}

// Create a write stream for the SQL file
const writeStream = fs.createWriteStream(sqlFilePath);

// Read and process the CSV file
fs.createReadStream(csvFilePath)
  .pipe(csv())
  .on('data', (row) => {
    // Generate SQL UPDATE query for each row
    const updateQuery = `UPDATE pm_session SET
      travel_before = ${formatValue(row.travel_before)},
      travel_after = ${formatValue(row.travel_after)},
      travel_number = ${formatValue(row.travel_number)},
      linked_before = '${row.travel_before === 'Linked' ? 'Y' : 'N'}',
      linked_after = '${row.travel_after === 'Linked' ? 'Y' : 'N'}',
      updated_by = 'FSY-2883'
      WHERE pm_session_id = ${row.pm_session_25};\n`;

    // Write the SQL query to the file
    writeStream.write(updateQuery);
  })
  .on('end', () => {
    // Close the write stream
    writeStream.end();
    console.log('CSV file successfully processed and SQL queries written to numbers.sql');
  });
