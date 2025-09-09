trigger ContentVersionTrigger on ContentVersion (after insert, after update) {
    
    if (Trigger.isAfter && (Trigger.isInsert || Trigger.isUpdate)) {
        
        List<ContentVersion> noteVersionsToProcess = new List<ContentVersion>();
        for (ContentVersion cv : Trigger.new) {
            if (cv.FileType == 'SNOTE') {
                
                if (Trigger.isInsert) {
                    noteVersionsToProcess.add(cv);
                } else if (Trigger.isUpdate) {
                    ContentVersion oldVersion = Trigger.oldMap.get(cv.Id);
                    if (cv.VersionData != oldVersion.VersionData || 
                        cv.Title != oldVersion.Title) {
                        noteVersionsToProcess.add(cv);
                    }
                }
            }
        }
        
        if (!noteVersionsToProcess.isEmpty()) {
            System.enqueueJob(new ContentVersionEmailProcessor(noteVersionsToProcess));
        }
    }
}