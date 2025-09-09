public class ServiceUtility {
    
    public class ApplicationResult {
        public Boolean isEligibleToApply { get; set; }
        public Application_Timeline__c currentTimeline { get; set; }
        public String message { get; set; }
        
        public ApplicationResult(Boolean eligible, Application_Timeline__c timeline, String msg) {
            this.isEligibleToApply = eligible;
            this.currentTimeline = timeline;
            this.message = msg;
        }
    }
    
    @AuraEnabled
    public static ApplicationResult checkApplicationEligibility(Id userId) {
        try {
            List<Application_Timeline__c> openTimelineList = [
                SELECT Id, Name, Program__c, Is_Application_Open__c,
                       ReportingCycle1StartDate__c, ReportingCycle1EndDate__c,
                       ReportingCycle2StartDate__c, ReportingCycle2EndDate__c
                FROM Application_Timeline__c 
                WHERE Program__c = 'GPS' 
                AND Is_Application_Open__c = true 
                LIMIT 1
            ];
            
            if (openTimelineList.isEmpty()) {
                return new ApplicationResult(false, null, 'No application timeline is currently open');
            }
            
            Application_Timeline__c currentTimeline = openTimelineList[0];
            
            Date today = Date.today();
            String currentCycle = getCurrentCycle(currentTimeline, today);
            
            if (String.isBlank(currentCycle)) {
                return new ApplicationResult(false, currentTimeline, 'Current date does not fall within any active cycle period');
            }
            
            Boolean hasAppliedInCurrentCycle = checkUserApplicationInCycle(userId, currentTimeline, currentCycle, today);
            
            if (hasAppliedInCurrentCycle) {
                return new ApplicationResult(false, currentTimeline, 'User has already applied for the current cycle');
            } else {
                return new ApplicationResult(true, currentTimeline, 'User is eligible to apply for current cycle: ' + currentCycle);
            }
            
        } catch (Exception e) {
            System.debug('Error in checkApplicationEligibility: ' + e.getMessage());
            return new ApplicationResult(false, null, 'Error occurred while checking application eligibility: ' + e.getMessage());
        }
    }
    

    private static String getCurrentCycle(Application_Timeline__c timeline, Date today) {
        // Check Cycle 1
        if (timeline.ReportingCycle1StartDate__c != null && timeline.ReportingCycle1EndDate__c != null) {
            if (today >= timeline.ReportingCycle1StartDate__c && today <= timeline.ReportingCycle1EndDate__c) {
                return 'Cycle1';
            }
        }
        
        // Check Cycle 2
        if (timeline.ReportingCycle2StartDate__c != null && timeline.ReportingCycle2EndDate__c != null) {
            if (today >= timeline.ReportingCycle2StartDate__c && today <= timeline.ReportingCycle2EndDate__c) {
                return 'Cycle2';
            }
        }
        
        return null; 
    }

    private static Boolean checkUserApplicationInCycle(Id userId, Application_Timeline__c timeline, String currentCycle, Date today) {
        Date cycleStartDate;
        Date cycleEndDate;
        
        // Get the date range for current cycle
        if (currentCycle == 'Cycle1') {
            cycleStartDate = timeline.ReportingCycle1StartDate__c;
            cycleEndDate = timeline.ReportingCycle1EndDate__c;
        } else if (currentCycle == 'Cycle2') {
            cycleStartDate = timeline.ReportingCycle2StartDate__c;
            cycleEndDate = timeline.ReportingCycle2EndDate__c;
        }

        List<Funding_Application__c> existingApplications = [
            SELECT Id 
            FROM Funding_Application__c 
            WHERE CreatedById = :userId 
            AND Date__c >= :cycleStartDate 
            AND Date__c <= :cycleEndDate
            AND Application_Timeline__c = :timeline.Id
            AND Application_Status__c = 'Submitted'
            LIMIT 1
        ];
        
        return !existingApplications.isEmpty();
    }
    
    @AuraEnabled
    public static Boolean isApplicationOpen() {
        List<Application_Timeline__c> timelineList = [
            SELECT Id 
            FROM Application_Timeline__c 
            WHERE Program__c = 'GPS' 
            AND Is_Application_Open__c = true 
            LIMIT 1
        ];
        return !timelineList.isEmpty();
    }
    
    @AuraEnabled
    public static Boolean isApplicationOpenWithUserEligibility(Id userId) {
        ApplicationResult result = checkApplicationEligibility(userId);
        return result.isEligibleToApply;
    }
    
    public static Application_Timeline__c getCurrentOpenTimeline() {
        List<Application_Timeline__c> timelineList = [
            SELECT Id, Name, Program__c, Is_Application_Open__c,
                   ReportingCycle1StartDate__c, ReportingCycle1EndDate__c,
                   ReportingCycle2StartDate__c, ReportingCycle2EndDate__c
            FROM Application_Timeline__c 
            WHERE Program__c = 'GPS' 
            AND Is_Application_Open__c = true 
            LIMIT 1
        ];
        
        return timelineList.isEmpty() ? null : timelineList[0];
    }
}