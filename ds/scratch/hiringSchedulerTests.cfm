dao = variables.injector.getInstance("dao@ds")

tests = [
  // 1
  "testDryRun"
  ,"testHappyPath"
  ,"testACHappyPath"
  ,"testTrainingAlreadyAssignedCN"
  ,"testTrainingAlreadyAssignedAC"
  ,"testAlreadyAssignedOneLinkedSession"
  ,"testCanadaSameProvince"
  ,"testTrainingTravelNull"
  ,"testTrainingTravelUtah"
  ,"testTrainingTravelFarFarAway"
  // 11
  ,"testTrainingClosestToFirstSession"
  ,"testResidenceUtah"
  ,"testResidenceOregon"
  ,"testResidenceUtahToOregon"
  ,"testTravelBalanceLocalOnly"
  ,"testTravelBalanceTravelOnly"
  ,"testTravelBalanceHappyPath"
  ,"testTravelBalanceSadPath"
  ,"testTravelUnbalancedButAssigned"
  ,"testBackToBack_Local_Travel"
  // 21
  ,"testBackToBack_Travel_Travel"
  ,"testBackToBack_Local_Travel_Travel"
  ,"testBackToBack_Travel_Travel_Local"
  ,"testBackToBack_Travel_Local_Travel_After"
  ,"testBackToBack_Travel_Local_Travel_Before"
  ,"testAlreadyAssignedOneAvailOneLinked"
  ,"testResidenceUSAtoCAN"
  ,"testResidenceCANtoUSA"
  ,"testAvailable6ConsecutiveWeeksWork5Break"
  ,"testAvailable7ConsecutiveWeeksWork5BreakWork1"
  // 31
  ,"testRespectPlaceTime"
  ,"testCanWorkTravelLinkConsecutiveWeeks"
  ,"testCanWork1TravelIn2ConsecutiveWeeksUnlinked"
  ,"testCanWorkUnlinkedNotTravelConsecutiveWeeks"
  ,"testLinkedSessions_1Local_2TravelLinked"
  ,"testLinkedSessions_3Travel2Linked_WillWork4_available3"
  ,"testLinkedSessions_3Travel2Linked_WillWork4_available2"
  ,"testLinkedSessions_3Travel2Linked_WillWork4_available1"
  ,"testLinkedSessions_3Linked" // Expected: 3 Actual: 0
  ,"testLinkedSessions_2Linked_OnlyAvailable1Week"
  // 41
  ,"testPeakWeeks"
  ,"testCAFirst_only_CA"
  ,"testCAFirst_1Local_2CA" // Expected: 10001695,10001618 Actual: 10001610,10001618
  ,"testCAFirst_1CA_1LocalAlreadyAssigned"
  ,"testTwoAvailSameWeek"
  ,"testTwoAvailNotLinkedNotLocal" // Expected: 1 Actual: 2
  ,"testTwoAvailLocal"
  ,"testTwoAvailLinkedNotLocal"
  ,"testTwoAvailLinkedWAIsWAResident"
  ,"testOneAvailPeakWeek"
  // 51
  ,"testDesirabilityNeutralThreeOptions"
  ,"testDesirabilityPositiveThreeOptions"
  ,"testDesirabilityNegativeThreeOptions"
  ,"testDesirabilityPositiveTwoOptions"
  ,"testDesirabilityNegativeTwoOptions"
  ,"testCoordinator"
  ,"testDesirabilityNegativeSubsequentWeeks" // Expected: ["10001685","10001694","10001738","80001990"] Actual: ["10001685","10001694","10001738","10001741"]
  ,"testDesirabilityPositiveSubsequentWeeks" // Expected: ["10001685","10001694","10001738","80001990"] Actual: ["10001685","10001694","10001738","10001741"]
  ,"testDesirabilityNeutralSubsequentWeeks"
  ,"testTwoLinkedAreTravelAdjacent" // Expected: 2 Actual: 3
  // 61
  ,"testAssignedOneLinkedOtherIsTravelAdjacent" // Expected: 1 Actual: 3
  ,"testAssignedTwoLinkedOfThreeWithMiddleUnassigned"
  ,"testAssignedOneLinkedOneUnlinkedWithMiddleUnassignedLinkedToAnAssigned" // Expected: 2 Actual: 3
  ,"testTrainingWeirdoProdIssue" // Expected: 7 Actual: 0
  ,"testAlreadyAssignedNoAutoAssignSession" // Expected: 3 Actual: 2
  ,"testPreferPeakWeeks"

  // DON'T RUN THIS. WE'RE NOT DOING IT.  NOT THE DROIDS ////////,"testDesirabilityNeutralTwoOptions"
]

// Run a block of 10 tests
//x = { start = 1, end = 10}
//x = { start = 11, end = 20}
//x = { start = 21, end = 30}
//x = { start = 31, end = 40}
//x = { start = 41, end = 50}
//x = { start = 51, end = 60}
//x = { start = 61, end = 66}

// Run an arbitrary range of tests
x = { start = 17, end = 20 }

// Indexes for blocks and ranges
testsToRun = []
for (i = x.start; i <= x.end; i++) {
	testsToRun.append(i)
}

// Run a specific list of tests
 testsToRun = [39] // 39, 43, 46, 57, 58, 60, 61, 63, 64, 65


for (i in testsToRun) {
  result = invoke(dao, tests[i])
  writedump(result)
}
