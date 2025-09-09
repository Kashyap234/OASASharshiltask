public class ContentVersionEmailProcessor implements Queueable {
    
    private List<ContentVersion> versionsToProcess;
    
    public ContentVersionEmailProcessor(List<ContentVersion> versions) {
        this.versionsToProcess = versions;
    }
    
    public void execute(QueueableContext context) {
        try {
            // Get ContentDocument IDs
            Set<Id> contentDocumentIds = new Set<Id>();
            for (ContentVersion cv : versionsToProcess) {
                contentDocumentIds.add(cv.ContentDocumentId);
            }
            
            // Get ContentNote data
            List<ContentNote> contentNotes = [
                SELECT Id, Title, Content, CreatedDate, LastModifiedDate
                FROM ContentNote 
                WHERE Id IN :contentDocumentIds
            ];
            
            // Get linked accounts for these notes
            Map<Id, Id> noteToAccountMap = getNoteToAccountMapping(contentDocumentIds);

            // *** EFFICIENCY IMPROVEMENT ***
            // Get all action words from metadata once to avoid querying in a loop.
            List<Action_Words__mdt> actionWords = [
                SELECT MasterLabel, Priority_Level__c 
                FROM Action_Words__mdt 
                WHERE Is_Activeis__c = true
            ];
            
            // Process each note for email
            for (ContentNote note : contentNotes) {
                Id accountId = noteToAccountMap.get(note.Id);
                if (accountId != null) {
                    // Pass the action words list to the analyzer method
                    ContentNoteAnalyzer.analyzeNoteAndSendEmail(note, accountId, actionWords);
                }
            }
            
        } catch (Exception e) {
            System.debug('Error in ContentVersionEmailProcessor: ' + e.getMessage());
        }
    }
    
    // Helper method to get note to account mapping
    private Map<Id, Id> getNoteToAccountMapping(Set<Id> contentDocumentIds) {
        Map<Id, Id> noteToAccountMap = new Map<Id, Id>();
        
        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId, LinkedEntityId 
            FROM ContentDocumentLink 
            WHERE ContentDocumentId IN :contentDocumentIds
        ];
        
        for (ContentDocumentLink link : links) {
            // Only map if the LinkedEntityId is an Account Id (starts with '001')
            if (String.valueOf(link.LinkedEntityId).startsWith('001')) {
                noteToAccountMap.put(link.ContentDocumentId, link.LinkedEntityId);
            }
        }
        
        return noteToAccountMap;
    }
}