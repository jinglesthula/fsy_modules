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
  ,"testTwoAvailSameWeek"
  ,"testIncompatibleTravelAfter"
  ,"testTwoCompatibleBeforeAfter"
  ,"testIncompatibleTravelBefore"
  ,"testTwoAvailLinkedWAIsWAResident"
  ,"testOneAvailPeakWeek"
  ,"testDesirabilityNeutralThreeOptions"
  ,"testDesirabilityPositiveThreeOptions"
  ,"testDesirabilityNegativeThreeOptions"
  // 51
  ,"testDesirabilityPositiveTwoOptions"
  ,"testDesirabilityNegativeTwoOptions"
  ,"testCoordinator"
  ,"testDesirabilityNegativeSubsequentWeeks"
  ,"testDesirabilityPositiveSubsequentWeeks"
  ,"testDesirabilityNeutralSubsequentWeeks"
  ,"testTwoLinkedAreTravelAdjacent"
  ,"testAssignedOneLinkedOtherIsTravelAdjacent"
  ,"testAssignedTwoLinkedOfThreeWithMiddleUnassigned"
  ,"testAssignedOneLinkedOneUnlinkedWithMiddleUnassignedLinkedToAnAssigned"
  // 61
  ,"testTrainingWeirdoProdIssue"
  ,"testAlreadyAssignedNoAutoAssignSession"
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
x = { start = 1, end = 63 }

// Indexes for blocks and ranges
testsToRun = []
for (i = x.start; i <= x.end; i++) {
	testsToRun.append(i)
}

// Run a specific list of tests
//testsToRun = [59] // 59


for (i in testsToRun) {
  result = invoke(dao, tests[i])
  writedump(result)
}
