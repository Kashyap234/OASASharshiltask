trigger ConsentFormTrigger on ConsentForm__c (after insert, after update) {
    if (Trigger.isAfter && (Trigger.isInsert || Trigger.isUpdate)) {
        List<ConsentForm__c> consentForms = Trigger.new;
        Map<Id, ConsentForm__c> oldMap = Trigger.oldMap;

        ConsentTriggerHelper.handleConsentFormApproval(consentForms, oldMap);
    }
}