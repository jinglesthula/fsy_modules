const fs = require('fs');
const parse = require('csv-parser');

const linkedSessions = [];
let currentLinkedSet = [];

// Open and read the CSV file
fs.createReadStream('./2025 Travel Criteria.csv')
  .pipe(parse({ columns: true, skip_empty_lines: true }))
  .on('data', (row) => {
    const sessionId = row['pm_session_25'];
    const travelBefore = row['travel_before'];
    const travelAfter = row['travel_after'];

    // Check if this row is linked
    if (travelAfter === 'Linked' || travelBefore === 'Linked') {
      // Add session ID to the current linked set
      currentLinkedSet.push(sessionId);
    }

    // We done here?
    if (travelAfter !== 'Linked' && currentLinkedSet.length > 0) {
      linkedSessions.push(currentLinkedSet);
      // Reset the current linked set for the next sequence
      currentLinkedSet = [];
    }
  })
  .on('end', () => {
    // Add the final set if we reached the end and it contains linked items
    if (currentLinkedSet.length > 1) {
      linkedSessions.push(currentLinkedSet);
    }

    // Output the result
    fs.writeFileSync('linked_sessions.json', JSON.stringify(linkedSessions, null, 2));

  })
  .on('error', (err) => {
    console.error('Error reading CSV file:', err);
  });

