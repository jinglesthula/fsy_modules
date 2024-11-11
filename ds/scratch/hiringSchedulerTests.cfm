dao = variables.injector.getInstance("dao@ds")

tests = [
  // 1
  "testDryRun"
  ,"testHappyPath"
  ,"testACHappyPath"
  ,"testTrainingAlreadyAssignedCN"
  ,"testTrainingAlreadyAssignedAC"
  ,"testAlreadyAssignedOneLinkedSession" // Expected: 2 Actual: 1
  ,"testCanadaSameProvince" // Expected: 2 Actual: 0
  ,"testTrainingTravelNull"
  ,"testTrainingTravelUtah"
  ,"testTrainingTravelFarFarAway"
  // 11
  ,"testTrainingClosestToFirstSession"
  ,"testResidenceUtah"
  ,"testResidenceOregon"
  ,"testResidenceUtahToOregon"
  ,"testTravelBalanceLocalOnly" // Expected: 3 Actual: 2
  ,"testTravelBalanceTravelOnly"
  ,"testTravelBalanceHappyPath" // Expected: 10001627,10001738,10001707,10001650 Actual: 10001685,10001694,10001627,10001717
  ,"testTravelBalanceSadPath" // Expected: 10001627,10001738,10001707,10001650 Actual: 10001685,10001694,10001627,10001650
  ,"testTravelUnbalancedButAssigned" // Expected: 4 Actual: 3
  ,"testBackToBack_Local_Travel" // Expected: 2 Actual: 0
  // 21
  ,"testBackToBack_Travel_Travel" // Expected: 1 Actual: 0
  ,"testBackToBack_Local_Travel_Travel"
  ,"testBackToBack_Travel_Travel_Local"
  ,"testBackToBack_Travel_Local_Travel_After" // Expected: 3 Actual: 2
  ,"testBackToBack_Travel_Local_Travel_Before" // Expected: 3 Actual: 2
  ,"testAlreadyAssignedOneAvailOneLinked"
  ,"testResidenceUSAtoCAN"
  ,"testResidenceCANtoUSA"
  ,"testAvailable6ConsecutiveWeeksWork5Break" // Expected: 5 Actual: 3
  ,"testAvailable7ConsecutiveWeeksWork5BreakWork1" // Expected: 6 Actual: 4
  // 31
  ,"testRespectPlaceTime" // Expected: 1 Actual: 0
  ,"testCanWorkTravelLinkConsecutiveWeeks"
  ,"testCanWork1TravelIn2ConsecutiveWeeksUnlinked"
  ,"testCanWorkUnlinkedNotTravelConsecutiveWeeks" // Expected: 2 Actual: 1
  ,"testLinkedSessions_1Local_2TravelLinked"
  ,"testLinkedSessions_1TravelLinked_1Local_1TravelLinked" // The symbol you provided testLinkedSessions_1TravelLinked_1Local_1TravelLinked is not the name of a function.
  ,"testLinkedSessions_3Linked"
  ,"testLinkedSessions_2Linked_OnlyAvailable1Week"
  ,"testPeakWeeks" // Expected: 1 Actual: 0
  ,"testCAFirst_only_CA" // Expected: 0 Actual: 1
  // 41
  ,"testCAFirst_1Local_2CA" // Expected: 2 Actual: 0
  ,"testCAFirst_1CA_1LocalAlreadyAssigned"
  ,"testTwoAvailSameWeek"
  ,"testTwoAvailNotLinkedNotLocal"
  ,"testTwoAvailLocal"
  ,"testTwoAvailLinkedNotLocal"
  ,"testTwoAvailLinkedWAIsWAResident"
  ,"testOneAvailPeakWeek"
  ,"testDesirabilityNeutralThreeOptions" // Expected: ["10001685","10001689","10001694","10001738"] Actual: ["10001685","10001694","10001738"]
  ,"testDesirabilityPositiveThreeOptions" // Expected: ["10001685","10001688","10001694","10001738"] Actual: ["10001685","10001694","10001738"]
  // 51
  ,"testDesirabilityNegativeThreeOptions" // Expected: ["10001685","10001690","10001694","10001738"] Actual: ["10001685","10001694","10001738"]
  ,"testOneAvailDesirabilityNeutralTwoOptions" // The symbol you provided testOneAvailDesirabilityNeutralTwoOptions is not the name of a function.
  ,"testDesirabilityPositiveTwoOptions" // Expected: ["10001685","10001689","10001694","10001738"] Actual: ["10001685","10001694","10001738"]
  ,"testDesirabilityNegativeTwoOptions" // Expected: ["10001685","10001689","10001694","10001738"] Actual: ["10001685","10001694","10001738"]
  ,"testCoordinator"
  ,"testDesirabilityNegativeSubsequentWeeks" // Expected: ["10001685","10001694","10001738","80001990"] Actual: ["10001685","10001694","10001738"]
  ,"testDesirabilityPositiveSubsequentWeeks" // Expected: ["10001685","10001694","10001738","80001990"] Actual: ["10001685","10001694","10001738"]
  ,"testDesirabilityNeutralSubsequentWeeks"
  ,"testTwoLinkedAreTravelAdjacent"
  ,"testAssignedOneLinkedOtherIsTravelAdjacent"
  // 61
  ,"testAssignedTwoLinkedOfThreeWithMiddleUnassigned" // Expected: 3 Actual: 2
  ,"testAssignedOneLinkedOneUnlinkedWithMiddleUnassignedLinkedToAnAssigned"
  ,"testTrainingWeirdoProdIssue" // Expected: 7 Actual: 4
  ,"testAlreadyAssignedNoAutoAssignSession" // Expected: 3 Actual: 2
  ,"testPreferPeakWeeks"

  // DON'T RUN THIS. WE'RE NOT DOING IT.  NOT THE DROIDS ////////,"testDesirabilityNeutralTwoOptions"
]

write a node.js script.  it should open a csv file in the current directory which will contain a header row (should be ignored) and data rows.  For each data row, columns 5 and 6 (travel_before and travel_after in the header row) will either be numeric, an `x` character, or the string `Linked`.
If a row has Linked in the 6th column, then the next row is linked to it.  That next row will also have Linked in column 6, indicating they are linked to each other.  Most linked sessions are in pairs, but there are some with an arbitrary number of linked sessions in sequence.

Example showing 2 linked rows, followed by an unlinked row:

travel_before,travel_after
x,Linked
Linked,4
3,4

Example showing an unlinked row, followed by 3 linked rows, followed by an unlinked row:

travel_before,travel_after
5,2
x,Linked
Linked,Linked
Linked,4
3,4

Column 3 will contain an id (the column is named pm_session_25).  The object of the script is to collect an array, where items in the array represent linked sets of sessions.  The items in the array should be an array with 2 or more linked pm_session_25 ids.  Unlinked rows are ignored.

// Run a block of 10 tests
//x = { start = 1, end = 10}
//x = { start = 11, end = 20}
//x = { start = 21, end = 30}
//x = { start = 31, end = 40}
//x = { start = 41, end = 50}
//x = { start = 51, end = 60}

// Run an arbitrary range of tests
x = { start = 61, end = 65 }

// Indexes for blocks and ranges
testsToRun = []
for (i = x.start; i <= x.end; i++) {
	testsToRun.append(i)
}

// Run a specific list of tests
testsToRun = [36, 40] // 6, 7, 17, 18, 19, 20, 24, 25, 36, 40, 41, 49, 50, 51, 52, 53, 54, 56, 57, 61, 63, 64


for (i in testsToRun) {
  result = invoke(dao, tests[i])
  writedump(result)
}
