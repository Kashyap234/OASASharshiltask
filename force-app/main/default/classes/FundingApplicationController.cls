public with sharing class FundingApplicationController {

    @AuraEnabled
    public static List<Funding_Application__c> getApplications() {
        try {
            return [
                SELECT Id, Name, Request_Type__c, Application_Status__c, Date__c
                FROM Funding_Application__c
                ORDER BY CreatedDate DESC
            ];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static String deleteApplication(String applicationId) {
        try {
            Funding_Application__c appToDelete = [SELECT Id FROM Funding_Application__c WHERE Id = :applicationId];
            delete appToDelete;
            return 'Success';
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static String getContentDistributionUrl(String documentId) {
        try {
            // Get the latest ContentVersion from the ContentDocumentId
            ContentVersion cv = [
                SELECT Id, Title
                FROM ContentVersion 
                WHERE ContentDocumentId = :documentId
                AND IsLatest = true
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            
            // Check if a ContentDistribution already exists for this version
            List<ContentDistribution> existingDistributions = [
                SELECT Id, DistributionPublicUrl 
                FROM ContentDistribution 
                WHERE ContentVersionId = :cv.Id
                LIMIT 1
            ];
            
            // If a distribution exists, return its public URL
            if (!existingDistributions.isEmpty()) {
                return existingDistributions[0].DistributionPublicUrl;
            }
            
            // If no distribution exists, create a new one
            ContentDistribution cd = new ContentDistribution();
            cd.Name = cv.Title;
            cd.ContentVersionId = cv.Id;
            cd.PreferencesAllowViewInBrowser = true;
            cd.PreferencesLinkLatestVersion = true;
            cd.PreferencesNotifyOnVisit = false;
            cd.PreferencesPasswordRequired = false;
            cd.PreferencesAllowOriginalDownload = true;
            
            insert cd;
            
            // After inserting, requery to get the generated DistributionPublicUrl
            ContentDistribution newCd = [
                SELECT Id, DistributionPublicUrl
                FROM ContentDistribution
                WHERE Id = :cd.Id
                LIMIT 1
            ];
            
            return newCd.DistributionPublicUrl;
            
        } catch (Exception e) {
            System.debug('Error creating content distribution: ' + e.getMessage());
            throw new AuraHandledException('Error creating content distribution: ' + e.getMessage());
        }
    }
}