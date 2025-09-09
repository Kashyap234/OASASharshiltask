public with sharing class DuplicateReferralController {
    
    @AuraEnabled(cacheable=true)
    public static List<Duplicate_Referral__c> getDuplicateReferrals() {
        try {
            return [
                SELECT Id, Name, JSON_Data__c, CreatedDate, LastModifiedDate,
                       Referral_Form__c,
                       Referral_Form__r.Id,
                       Referral_Form__r.What_type_of_referral_is_this__c,
                       Referral_Form__r.School_Name__c,
                       Referral_Form__r.ParentGuardianAdultFirstName__c,
                       Referral_Form__r.ParentGuardianAdultLastName__c,
                       Referral_Form__r.ParentGuardianAdultPhoneNumber__c,
                       Referral_Form__r.ParentGuardianAdultEmail__c,
                       Referral_Form__r.ReasonForReferral__c,
                       Referral_Form__r.OtherReasonForReferral__c,
                       Referral_Form__r.KindlyDetailReasonForReferral__c,
                       Referral_Form__r.NameOfReferralSource__c,
                       Referral_Form__r.ReferralSourcePhoneNumber__c,
                       Referral_Form__r.ReferralSourceEmail__c,
                       Referral_Form__r.SchoolStaffMemberRole__c,
                       Referral_Form__r.CreatedDate
                FROM Duplicate_Referral__c 
                ORDER BY CreatedDate DESC 
                LIMIT 100
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving duplicate referrals: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static void markAsDuplicate(Id duplicateReferralId) {
        try {
            Duplicate_Referral__c duplicateRecord = [
                SELECT Id, JSON_Data__c 
                FROM Duplicate_Referral__c 
                WHERE Id = :duplicateReferralId 
                LIMIT 1
            ];
            
            // Update the duplicate record status
            // duplicateRecord.Status__c = 'Confirmed Duplicate';
            // duplicateRecord.Resolution_Date__c = System.now();
            // duplicateRecord.Resolved_By__c = UserInfo.getUserId();
            
            update duplicateRecord;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error marking as duplicate: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static Id markAsNotDuplicate(Id duplicateReferralId) {
        try {
            Duplicate_Referral__c duplicateRecord = [
                SELECT Id, JSON_Data__c 
                FROM Duplicate_Referral__c 
                WHERE Id = :duplicateReferralId 
                LIMIT 1
            ];
            
            // Parse the JSON data and create a new Referral_Form__c record
            Map<String, Object> jsonData = (Map<String, Object>) JSON.deserializeUntyped(duplicateRecord.JSON_Data__c);
            Map<String, Object> referralFormData = (Map<String, Object>) jsonData.get('referralFormData');
            
            Referral_Form__c newReferral = new Referral_Form__c();
            
            // Map the fields from JSON to the new record
            if (referralFormData != null) {
                mapJsonFieldsToReferralForm(referralFormData, newReferral);
            }
            
            // Insert the new referral form
            insert newReferral;
            
            // Update the duplicate record status
            // duplicateRecord.Status__c = 'Not a Duplicate';
            // duplicateRecord.Resolution_Date__c = System.now();
            // duplicateRecord.Resolved_By__c = UserInfo.getUserId();
            // duplicateRecord.Created_Referral__c = newReferral.Id;
            
            update duplicateRecord;
            
            return newReferral.Id;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error creating referral from duplicate: ' + e.getMessage());
        }
    }
    
    private static void mapJsonFieldsToReferralForm(Map<String, Object> jsonData, Referral_Form__c referralForm) {
        // Map each field from the JSON to the Referral_Form__c record
        if (jsonData.containsKey('What_type_of_referral_is_this__c')) {
            referralForm.What_type_of_referral_is_this__c = (String) jsonData.get('What_type_of_referral_is_this__c');
        }
        if (jsonData.containsKey('School_Name__c')) {
            referralForm.School_Name__c = (String) jsonData.get('School_Name__c');
        }
        if (jsonData.containsKey('ParentGuardianAdultFirstName__c')) {
            referralForm.ParentGuardianAdultFirstName__c = (String) jsonData.get('ParentGuardianAdultFirstName__c');
        }
        if (jsonData.containsKey('ParentGuardianAdultLastName__c')) {
            referralForm.ParentGuardianAdultLastName__c = (String) jsonData.get('ParentGuardianAdultLastName__c');
        }
        if (jsonData.containsKey('ParentGuardianAdultPhoneNumber__c')) {
            Object phoneValue = jsonData.get('ParentGuardianAdultPhoneNumber__c');
            if (phoneValue != null) {
                referralForm.ParentGuardianAdultPhoneNumber__c = Decimal.valueOf(String.valueOf(phoneValue));
            }
        }
        if (jsonData.containsKey('ParentGuardianAdultEmail__c')) {
            referralForm.ParentGuardianAdultEmail__c = (String) jsonData.get('ParentGuardianAdultEmail__c');
        }
        if (jsonData.containsKey('ReasonForReferral__c')) {
            referralForm.ReasonForReferral__c = (String) jsonData.get('ReasonForReferral__c');
        }
        if (jsonData.containsKey('OtherReasonForReferral__c')) {
            referralForm.OtherReasonForReferral__c = (String) jsonData.get('OtherReasonForReferral__c');
        }
        if (jsonData.containsKey('KindlyDetailReasonForReferral__c')) {
            referralForm.KindlyDetailReasonForReferral__c = (String) jsonData.get('KindlyDetailReasonForReferral__c');
        }
        if (jsonData.containsKey('NameOfReferralSource__c')) {
            referralForm.NameOfReferralSource__c = (String) jsonData.get('NameOfReferralSource__c');
        }
        if (jsonData.containsKey('ReferralSourcePhoneNumber__c')) {
            referralForm.ReferralSourcePhoneNumber__c = (Decimal) jsonData.get('ReferralSourcePhoneNumber__c');
        }
        if (jsonData.containsKey('ReferralSourceEmail__c')) {
            referralForm.ReferralSourceEmail__c = (String) jsonData.get('ReferralSourceEmail__c');
        }
        if (jsonData.containsKey('SchoolStaffMemberRole__c')) {
            referralForm.SchoolStaffMemberRole__c = (String) jsonData.get('SchoolStaffMemberRole__c');
        }
    }
}