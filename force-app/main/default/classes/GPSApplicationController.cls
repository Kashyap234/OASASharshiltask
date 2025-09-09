public with sharing class GPSApplicationController {
    
    @AuraEnabled
    public static Boolean isApplicationOpen() {
        return GPSApplicationDataService.isApplicationOpen();
    }

    @AuraEnabled
    public static Id createFundingApplication(Map<String, Object> applicationData) {
        return GPSApplicationDataService.createFundingApplication(applicationData);
    }

    @AuraEnabled
    public static Id updateFundingApplication(Id applicationId, Map<String, Object> applicationData) {
        return GPSApplicationDataService.updateFundingApplication(applicationId, applicationData);
    }

    @AuraEnabled
    public static Map<String, Object> getFundingApplication(Id applicationId) {
        return GPSApplicationGetDataHelper.getFundingApplication(applicationId);
    }
    
    @AuraEnabled(cacheable=true)
    public static User getCurrentUser() {
        return GPSApplicationGetDataHelper.getCurrentUser();
    }
}