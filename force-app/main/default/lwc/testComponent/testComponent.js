import { LightningElement, api, track, wire } from 'lwc';
import { getPicklistValues } from 'lightning/uiObjectInfoApi';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

// Schema Imports
import ABATEMENT_STRATEGY_OBJECT from '@salesforce/schema/Abatement_Strategy__c';
import STRATEGIES_OBJECT from '@salesforce/schema/Strategies__c';
import CORE_STRATEGIES_FIELD from '@salesforce/schema/Abatement_Strategy__c.Core_Strategies__c';
import CORE_ABATEMENT_STRATEGIES_FIELD from '@salesforce/schema/Abatement_Strategy__c.Core_Abatement_Strategies__c';
import IS_STRATEGY_INITIAL_FIELD from '@salesforce/schema/Strategies__c.Is_your_Strategy_Initial_Continuation__c';

export default class GPSformStepThree extends LightningElement {
    @track _partnerStrategies = {};
    @track selectedCoreStrategies = [];
    @track selectedAbatementStrategies = [];
    @track strategyData = {};
    @track strategyResourcesData = {};
    
    @track _coreStrategyOptions = [];
    @track coreAbatementStrategyOptions = [];
    @track initialContinuationOptions = [];
    
    isDataInitialized = false;

    @api 
    get partnerStrategies() {
        return this._partnerStrategies;
    }
    set partnerStrategies(data) {
        if (data) {
            // Deep clone to prevent shared object references
            const deepClonedData = JSON.parse(JSON.stringify(data));
            this._partnerStrategies = deepClonedData;
            this.initializeComponentState(deepClonedData);
        }
    }

    initializeComponentState(data) {
        this.selectedCoreStrategies = data.selectedCoreStrategies || [];
        this.selectedAbatementStrategies = data.selectedAbatementStrategies || [];
        this.strategyData = data.strategyData || {};
        this.strategyResourcesData = data.strategyResourcesData || {};
        this.isDataInitialized = true;
    }

    // --- WIRE SERVICES for Picklists ---
    @wire(getObjectInfo, { objectApiName: ABATEMENT_STRATEGY_OBJECT }) objectInfo;
    @wire(getObjectInfo, { objectApiName: STRATEGIES_OBJECT }) strategiesObjectInfo;

    @wire(getPicklistValues, { recordTypeId: '$objectInfo.data.defaultRecordTypeId', fieldApiName: CORE_STRATEGIES_FIELD })
    wiredCoreStrategies({ data, error }) {
        if (data) {
            this._coreStrategyOptions = data.values.map(value => ({ label: value.label, value: value.value }));
        } else if (error) { this.showToast('Error', 'Failed to load Core Strategies.', 'error'); }
    }

    @wire(getPicklistValues, { recordTypeId: '$objectInfo.data.defaultRecordTypeId', fieldApiName: CORE_ABATEMENT_STRATEGIES_FIELD })
    wiredCoreAbatementStrategies({ data, error }) {
        if (data) {
            this.coreAbatementStrategyOptions = data.values.map(value => ({ label: value.label, value: value.value }));
        } else if (error) { this.showToast('Error', 'Failed to load Abatement Strategies.', 'error'); }
    }

    @wire(getPicklistValues, { recordTypeId: '$strategiesObjectInfo.data.defaultRecordTypeId', fieldApiName: IS_STRATEGY_INITIAL_FIELD })
    wiredInitialContinuationPicklist({ data, error }) {
        if (data) { this.initialContinuationOptions = data.values; }
        else if (error) { console.error('Failed to load Initial/Continuation picklist:', error); }
    }

    // --- GETTERS for Dynamic UI ---
    get coreStrategyOptions() {
        if (!this.isDataInitialized) return [];
        return this._coreStrategyOptions.map((strategy) => {
            const isSelected = this.selectedCoreStrategies.includes(strategy.value);
            const strategyLetter = strategy.value.split(':')[0].trim();
            return {
                ...strategy,
                isSelected,
                headerClass: `strategy-header ${isSelected ? 'selected-core-strategy' : ''}`,
                filteredAbatementOptions: this.getFilteredAbatementOptionsForStrategy(strategyLetter)
            };
        });
    }

    getFilteredAbatementOptionsForStrategy(strategyLetter) {
        return this.coreAbatementStrategyOptions
            .filter(option => option.label.startsWith(strategyLetter + '.'))
            .map((option) => {
                const isSelected = this.selectedAbatementStrategies.includes(option.value);
                return {
                    ...option,
                    isSelected,
                    itemClass: `abatement-item ${isSelected ? 'selected' : ''}`,
                    strategyFormData: this.getStrategyFormData(option.value),
                    personnelData: this.getPersonnelData(option.value),
                    budgetData: this.getBudgetData(option.value)
                };
            });
    }

    // --- EVENT HANDLERS for UI Interaction ---
    handleCoreStrategyClick(event) {
        const strategyValue = event.currentTarget.dataset.strategyValue;
        if (this.selectedCoreStrategies.includes(strategyValue)) {
            this.selectedCoreStrategies = this.selectedCoreStrategies.filter(val => val !== strategyValue);
        } else {
            this.selectedCoreStrategies = [...this.selectedCoreStrategies, strategyValue];
        }
        this.notifyParentOfDataChange();
    }

    handleAbatementCardClick(event) {
        const optionValue = event.currentTarget.dataset.optionValue;
        if (this.selectedAbatementStrategies.includes(optionValue)) {
            this.selectedAbatementStrategies = this.selectedAbatementStrategies.filter(val => val !== optionValue);
            this.clearStrategyFormData(optionValue);
        } else {
            this.selectedAbatementStrategies = [...this.selectedAbatementStrategies, optionValue];
            this.initializeStrategyFormData(optionValue);
        }
        this.notifyParentOfDataChange();
    }
    
    // Other handlers (handleClearAbatement, handleStrategyFieldChange, etc.) remain the same...

    // --- HELPER METHODS ---
    getStrategyFormData(strategyValue) {
        return this.strategyData[strategyValue] || { budgetAmount: '', isInitialContinuation: '', budgetNarrative: '', implementationPlan: '', outcomeMeasures: '', processMeasures: '' };
    }

    getPersonnelData(strategyValue) {
        return this.strategyResourcesData[strategyValue]?.personnel || [];
    }
    
    getBudgetData(strategyValue) {
        return this.strategyResourcesData[strategyValue]?.budget || [];
    }

    initializeStrategyFormData(strategyValue) {
        if (!this.strategyData[strategyValue]) {
            this.strategyData[strategyValue] = { budgetAmount: '', isInitialContinuation: '', budgetNarrative: '', implementationPlan: '', outcomeMeasures: '', processMeasures: '' };
        }
        if (!this.strategyResourcesData[strategyValue]) {
            this.strategyResourcesData[strategyValue] = {
                personnel: [],
                budget: []
            };
        }
        this.strategyData = {...this.strategyData};
        this.strategyResourcesData = {...this.strategyResourcesData};
    }

    clearStrategyFormData(strategyValue) {
        delete this.strategyData[strategyValue];
        delete this.strategyResourcesData[strategyValue];
        this.strategyData = {...this.strategyData};
        this.strategyResourcesData = {...this.strategyResourcesData};
    }

    notifyParentOfDataChange() {
        const detail = {
            selectedCoreStrategies: this.selectedCoreStrategies,
            selectedAbatementStrategies: this.selectedAbatementStrategies,
            strategyData: this.strategyData,
            strategyResourcesData: this.strategyResourcesData
        };
        this.dispatchEvent(new CustomEvent('datachange', { detail, bubbles: true, composed: true }));
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
    
    // All other methods like row management (add/remove personnel/budget) remain the same.
}