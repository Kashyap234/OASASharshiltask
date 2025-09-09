public class ContentNoteAnalyzer {
    
    public class NoteAnalysisResult {
        @AuraEnabled public String noteId { get; set; }
        @AuraEnabled public String title { get; set; }
        @AuraEnabled public String content { get; set; }
        @AuraEnabled public Date createdDate { get; set; }
        @AuraEnabled public Date lastModifiedDate { get; set; }
        @AuraEnabled public List<String> matchedWords { get; set; }
        @AuraEnabled public String importanceLevel { get; set; }
        @AuraEnabled public Integer matchCount { get; set; }
        
        public NoteAnalysisResult() {
            this.matchedWords = new List<String>();
            this.matchCount = 0;
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<NoteAnalysisResult> getAnalyzedNotesForAccount(Id accountId) {
        List<NoteAnalysisResult> results = new List<NoteAnalysisResult>();
        
        try {
            // Get all action words from metadata
            List<Action_Words__mdt> actionWords = [
                SELECT MasterLabel, DeveloperName, Priority_Level__c 
                FROM Action_Words__mdt 
                WHERE Is_ActiveIs__c = true
                ORDER BY Priority_Level__c DESC
            ];
            
            if (actionWords.isEmpty()) {
                return results;
            }
            
            // Get content notes for the account
            List<ContentNote> contentNotes = getNotesForAccount(accountId);
            
            if (contentNotes.isEmpty()) {
                return results;
            }
            
            // Analyze each note
            for (ContentNote note : contentNotes) {
                NoteAnalysisResult result = analyzeNote(note, actionWords);
                results.add(result);
            }
            
        } catch (Exception e) {
            System.debug('Error in getAnalyzedNotesForAccount: ' + e.getMessage());
        }
        
        return results;
    }
    
    public static List<ContentNote> getNotesForAccount(Id accountId) {
        List<ContentNote> contentNotes = new List<ContentNote>();
        
        List<ContentDocumentLink> contentDocumentLinks = [
            SELECT ContentDocumentId 
            FROM ContentDocumentLink 
            WHERE LinkedEntityId = :accountId
        ];
        
        if (!contentDocumentLinks.isEmpty()) {
            Set<Id> contentDocumentIds = new Set<Id>();
            for (ContentDocumentLink contentDocumentLink : contentDocumentLinks) {
                contentDocumentIds.add(contentDocumentLink.ContentDocumentId);
            }
            
            contentNotes = [
                SELECT Id, Title, Content, CreatedDate, LastModifiedDate
                FROM ContentNote 
                WHERE Id IN :contentDocumentIds
            ];
        }
        
        return contentNotes;
    }
    
    private static NoteAnalysisResult analyzeNote(ContentNote note, List<Action_Words__mdt> actionWords) {
        NoteAnalysisResult result = new NoteAnalysisResult();
        result.noteId = note.Id;
        result.title = note.Title;
        result.content = note.Content != null ? note.Content.toString() : '';
        result.createdDate = note.CreatedDate.date();
        result.lastModifiedDate = note.LastModifiedDate.date();
        
        String contentLower = result.content.toLowerCase();
        Integer highPriorityMatches = 0;
        Integer mediumPriorityMatches = 0;
        Integer lowPriorityMatches = 0;
        
        // Check for each action word in the content
        for (Action_Words__mdt actionWord : actionWords) {
            String wordLower = actionWord.MasterLabel.toLowerCase();
            
            if (contentLower.contains(wordLower)) {
                result.matchedWords.add(actionWord.MasterLabel);
                result.matchCount++;
                
                // Count by priority level
                Decimal priority = actionWord.Priority_Level__c != null ? actionWord.Priority_Level__c : 1;
                if (priority >= 3) {
                    highPriorityMatches++;
                } else if (priority >= 2) {
                    mediumPriorityMatches++;
                } else {
                    lowPriorityMatches++;
                }
            }
        }
        
        // Determine importance level based on matches
        if (highPriorityMatches > 0) {
            result.importanceLevel = 'HIGH';
        } else if (mediumPriorityMatches > 0) {
            result.importanceLevel = 'MEDIUM';
        } else if (lowPriorityMatches > 0) {
            result.importanceLevel = 'LOW';
        } else {
            result.importanceLevel = 'NONE';
        }
        
        return result;
    }
    
    // Method for testing and debugging
    public static void displayNoteAnalysis(Id accountId) {
        List<NoteAnalysisResult> results = getAnalyzedNotesForAccount(accountId);
        
        System.debug('=== CONTENT NOTE ANALYSIS ===');
        for (NoteAnalysisResult result : results) {
            System.debug('Note: ' + result.title);
            System.debug('Importance: ' + result.importanceLevel);
            System.debug('Matched Words: ' + String.join(result.matchedWords, ', '));
            System.debug('Match Count: ' + result.matchCount);
            System.debug('Content: ' + (result.content.length() > 100 ? 
                         result.content.substring(0, 100) + '...' : result.content));
            System.debug('---');
        }
    }

        public static void analyzeNoteAndSendEmail(ContentNote note, Id accountId, List<Action_Words__mdt> actionWords) {
        // Step 1: Analyze the note using the existing helper method
        NoteAnalysisResult result = analyzeNote(note, actionWords);

        // Step 2: Proceed only if important words were found (e.g., not 'NONE' or 'LOW')
        if (result.importanceLevel == 'HIGH' || result.importanceLevel == 'MEDIUM') {
            
            // Step 3: Get the related Account Owner's email
            Account relatedAccount = [SELECT Owner.Email, Name FROM Account WHERE Id = :accountId LIMIT 1];
            
            if (relatedAccount != null && String.isNotBlank(relatedAccount.Owner.Email)) {
                
                // Step 4: Create and send the email
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                
                String[] toAddresses = new String[] { relatedAccount.Owner.Email };
                mail.setToAddresses(toAddresses);
                
                mail.setSubject('Important Note Added for Account: ' + relatedAccount.Name);
                
                // Construct the email body
                String body = 'An important note has been added or updated on the account: ' + relatedAccount.Name + '.\n\n';
                body += 'Note Title: ' + result.title + '\n';
                body += 'Importance Level: ' + result.importanceLevel + '\n';
                body += 'Matched Keywords: ' + String.join(result.matchedWords, ', ') + '\n\n';
                
                // Use plain text content and strip any HTML for clarity
                String plainTextContent = result.content.stripHtmlTags();
                body += 'Content Preview:\n' + (plainTextContent.length() > 500 ? plainTextContent.substring(0, 500) + '...' : plainTextContent);

                mail.setPlainTextBody(body);

                try {
                    Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
                } catch (Exception e) {
                    System.debug('Failed to send note analysis email. Error: ' + e.getMessage());
                }
            }
        }
    }
}