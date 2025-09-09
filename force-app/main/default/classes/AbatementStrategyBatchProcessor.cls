public class AbatementStrategyBatchProcessor implements Queueable {
    private Id abatementStrategyId;
    private List<String> remainingValues;
    
    public AbatementStrategyBatchProcessor(Id strategyId, List<String> values) {
        this.abatementStrategyId = strategyId;
        this.remainingValues = values;
    }
    
    public void execute(QueueableContext context) {
        try {
            Integer BATCH_SIZE = 90;
            
            // Get current record
            Abatement_Strategy__c strategy = [SELECT Id, Approved_Abatement_Strategies__c 
                                            FROM Abatement_Strategy__c 
                                            WHERE Id = :abatementStrategyId LIMIT 1];
            
            // Process next batch
            List<String> nextBatch = new List<String>();
            Integer endIndex = Math.min(BATCH_SIZE, remainingValues.size());
            
            for (Integer i = 0; i < endIndex; i++) {
                nextBatch.add(remainingValues[i]);
            }
            
            // Append to existing values
            if (String.isNotBlank(strategy.Approved_Abatement_Strategies__c)) {
                strategy.Approved_Abatement_Strategies__c += ';' + String.join(nextBatch, ';');
            } else {
                strategy.Approved_Abatement_Strategies__c = String.join(nextBatch, ';');
            }
            
            update strategy;
            
            // If more batches remain, queue next job
            if (remainingValues.size() > BATCH_SIZE) {
                List<String> nextRemainingValues = new List<String>();
                for (Integer i = BATCH_SIZE; i < remainingValues.size(); i++) {
                    nextRemainingValues.add(remainingValues[i]);
                }
                System.enqueueJob(new AbatementStrategyBatchProcessor(abatementStrategyId, nextRemainingValues));
            }
            
            System.debug('Processed batch of ' + nextBatch.size() + ' strategies. Remaining: ' + 
                        (remainingValues.size() - BATCH_SIZE));
            
        } catch (Exception e) {
            System.debug('Error in AbatementStrategyBatchProcessor: ' + e.getMessage());
        }
    }
}