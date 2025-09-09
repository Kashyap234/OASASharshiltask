import { LightningElement, api, track, wire } from 'lwc';
import { getPicklistValues } from 'lightning/uiObjectInfoApi';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import { getRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import ABATEMENT_STRATEGY_OBJECT from '@salesforce/schema/Abatement_Strategy__c';
import STRATEGIES_OBJECT from '@salesforce/schema/Strategies__c';

import CORE_STRATEGIES_FIELD from '@salesforce/schema/Abatement_Strategy__c.Core_Strategies__c';
import CORE_ABATEMENT_STRATEGIES_FIELD from '@salesforce/schema/Abatement_Strategy__c.Core_Abatement_Strategies__c';
import APPROVED_USES_FIELD from '@salesforce/schema/Abatement_Strategy__c.Approved_Uses__c';
import APPROVED_ABATEMENT_STRATEGIES_FIELD from '@salesforce/schema/Abatement_Strategy__c.Approved_Abatement_Strategies__c';

import IS_STRATEGY_INITIAL_FIELD from '@salesforce/schema/Strategies__c.Is_your_Strategy_Initial_Continuation__c';
import StrategyValidationUtil from './strategyValidationUtil';


export default class GpsFormStepThree extends LightningElement {
    @api abatementStrategyId;

    @track strategyData = {};
    @track strategyResourcesData = {};
    @track initialContinuationOptions = [];

    @track selectedCoreStrategies = [];
    @track _coreStrategyOptions = [];
    @track coreAbatementStrategyOptions = [];
    @track selectedCoreAbatements = [];
    @track expandedCoreStrategies = [];

    @track selectedApprovedUses = [];
    @track _approvedUseOptions = [];
    @track approvedAbatementStrategyOptions = [];
    @track selectedApprovedAbatements = [];
    @track expandedApprovedUses = [];

    @wire(getObjectInfo, { objectApiName: ABATEMENT_STRATEGY_OBJECT }) objectInfo;
    @wire(getObjectInfo, { objectApiName: STRATEGIES_OBJECT }) strategiesObjectInfo;

    @wire(getPicklistValues, { recordTypeId: '$objectInfo.data.defaultRecordTypeId', fieldApiName: CORE_STRATEGIES_FIELD })
    wiredCoreStrategies({ data, error }) {
        if (data) this._coreStrategyOptions = data.values.map(v => ({ ...v }));
        else if (error) this.showToast('Error', 'Failed to load Core Strategies.', 'error');
    }

    @wire(getPicklistValues, { recordTypeId: '$objectInfo.data.defaultRecordTypeId', fieldApiName: CORE_ABATEMENT_STRATEGIES_FIELD })
    wiredCoreAbatementStrategies({ data, error }) {
        if (data) this.coreAbatementStrategyOptions = data.values.map(v => ({ ...v }));
        else if (error) this.showToast('Error', 'Failed to load Abatement Strategies.', 'error');
    }

    @wire(getPicklistValues, { recordTypeId: '$objectInfo.data.defaultRecordTypeId', fieldApiName: APPROVED_USES_FIELD })
    wiredApprovedUses({ data, error }) {
        if (data) this._approvedUseOptions = data.values.map(v => ({ ...v }));
        else if (error) this.showToast('Error', 'Failed to load Approved Uses.', 'error');
    }

    @wire(getPicklistValues, { recordTypeId: '$objectInfo.data.defaultRecordTypeId', fieldApiName: APPROVED_ABATEMENT_STRATEGIES_FIELD })
    wiredApprovedAbatementStrategies({ data, error }) {
        console.log('Wired Approved Abatement Strategies:', data, error);

        if (data) this.approvedAbatementStrategyOptions = data.values.map(v => ({ ...v }));
        else if (error) this.showToast('Error', 'Failed to load Approved Abatement Strategies.', 'error');
    }

    @wire(getPicklistValues, { recordTypeId: '$strategiesObjectInfo.data.defaultRecordTypeId', fieldApiName: IS_STRATEGY_INITIAL_FIELD })
    wiredInitialContinuationPicklist({ data, error }) {
        if (data) this.initialContinuationOptions = data.values;
        else if (error) console.error('Error loading Initial/Continuation picklist', error);
    }

    @wire(getRecord, {
        recordId: '$abatementStrategyId',
        fields: [CORE_STRATEGIES_FIELD, CORE_ABATEMENT_STRATEGIES_FIELD, APPROVED_USES_FIELD, APPROVED_ABATEMENT_STRATEGIES_FIELD]
    })
    wiredRecord({ data, error }) {
        if (data) {
            this.selectedCoreStrategies = this.splitString(data.fields.Core_Strategies__c.value);
            this.selectedCoreAbatements = this.splitString(data.fields.Core_Abatement_Strategies__c.value);
            this.expandedCoreStrategies = [...this.selectedCoreStrategies];

            this.selectedApprovedUses = this.splitString(data.fields.Approved_Uses__c.value);
            this.selectedApprovedAbatements = this.splitString(data.fields.Approved_Abatement_Strategies__c.value);
            this.expandedApprovedUses = [...this.selectedApprovedUses];

            this.notifyParentOfDataChange();
        } else if (error) {
            console.warn('Could not load existing record data. This is expected for new records.', error);
        }
    }

    connectedCallback() {
        console.log('GPSFormStepThree connectedCallback');
        console.log('Strategies ', JSON.stringify(this.strategyData));
    }

    get coreStrategyOptions() {
        return this._coreStrategyOptions.map(strategy => {
            const isSelected = this.selectedCoreStrategies.includes(strategy.value);
            const isExpanded = this.expandedCoreStrategies.includes(strategy.value);
            const strategyLetter = strategy.value.split(':')[0].trim();
            return {
                ...strategy, isSelected, isExpanded,
                headerClass: `strategy-header ${isSelected ? 'selected-core-strategy' : ''}`,
                filteredAbatementOptions: this.getFilteredOptions(strategyLetter, this.coreAbatementStrategyOptions, this.selectedCoreAbatements)
            };
        });
    }

    get approvedUseOptions() {
        return this._approvedUseOptions.map(strategy => {
            const isSelected = this.selectedApprovedUses.includes(strategy.value);
            const isExpanded = this.expandedApprovedUses.includes(strategy.value);
            const strategyLetter = strategy.value.split(':')[0].trim();
            return {
                ...strategy, isSelected, isExpanded,
                headerClass: `strategy-header ${isSelected ? 'selected-core-strategy' : ''}`,
                filteredAbatementOptions: this.getFilteredOptions(strategyLetter, this.approvedAbatementStrategyOptions, this.selectedApprovedAbatements)
            };
        });
    }

    getFilteredOptions(strategyLetter, allChildOptions, selectedChildren) {
        return allChildOptions
            .filter(option => option.label.startsWith(strategyLetter + '.'))
            .map(option => ({
                ...option,
                isSelected: selectedChildren.includes(option.value),
                itemClass: `abatement-item ${selectedChildren.includes(option.value) ? 'selected' : ''}`,
                strategyFormData: this.getStrategyFormData(option.value),
                personnelData: this.getPersonnelData(option.value),
                budgetData: this.getBudgetData(option.value)
            }));
    }

    handleCoreStrategyClick(event) { this.toggleExpand(event.currentTarget.dataset.strategyValue, 'core'); }
    handleCoreAbatementClick(event) { this.toggleChildSelection(event, 'core'); }
    handleClearCoreAbatement(event) {
        event.stopPropagation();
        console.log('Selected ', JSON.stringify(this.selectedCoreAbatements));
        this.toggleChildSelection(event, 'core', true);
    }

    handleApprovedUseClick(event) { this.toggleExpand(event.currentTarget.dataset.strategyValue, 'approved'); }
    handleApprovedAbatementClick(event) { this.toggleChildSelection(event, 'approved'); }
    handleClearApprovedAbatement(event) { event.stopPropagation(); this.toggleChildSelection(event, 'approved', true); }

    toggleExpand(strategyValue, type) {
        if (type === 'core') {
            const expanded = this.expandedCoreStrategies;
            if (expanded.includes(strategyValue)) {
                this.expandedCoreStrategies = expanded.filter(v => v !== strategyValue);
            } else {
                this.expandedCoreStrategies = [...expanded, strategyValue];
            }
        } else if (type === 'approved') {
            const expanded = this.expandedApprovedUses;
            if (expanded.includes(strategyValue)) {
                this.expandedApprovedUses = expanded.filter(v => v !== strategyValue);
            } else {
                this.expandedApprovedUses = [...expanded, strategyValue];
            }
        }
    }

    toggleChildSelection(event, type, isClear = false) {
        const { optionValue, strategyValue } = event.currentTarget.dataset;

        const selectedParents = type === 'core' ? this.selectedCoreStrategies : this.selectedApprovedUses;
        const selectedChildren = type === 'core' ? this.selectedCoreAbatements : this.selectedApprovedAbatements;

        const isSelected = selectedChildren.includes(optionValue);
        let newSelectedChildren;
        let newSelectedParents = [...selectedParents];

        if (isSelected || isClear) {
            newSelectedChildren = selectedChildren.filter(v => v !== optionValue);
            this.clearStrategyFormData(optionValue);
        } else {
            newSelectedChildren = [...selectedChildren, optionValue];
            this.initializeStrategyFormData(optionValue);
            if (!newSelectedParents.includes(strategyValue)) {
                newSelectedParents = [...newSelectedParents, strategyValue];
            }
        }

        if (type === 'core') {
            this.selectedCoreAbatements = newSelectedChildren;
            this.selectedCoreStrategies = newSelectedParents;
            this.updateParentSelectionState(strategyValue, 'core');
        } else {
            this.selectedApprovedAbatements = newSelectedChildren;
            this.selectedApprovedUses = newSelectedParents;
            this.updateParentSelectionState(strategyValue, 'approved');
        }
        this.notifyParentOfDataChange();
    }

    updateParentSelectionState(parentValue, type) {
        const strategyLetter = parentValue.split(':')[0].trim();
        const allChildOptions = type === 'core' ? this.coreAbatementStrategyOptions : this.approvedAbatementStrategyOptions;
        const selectedChildren = type === 'core' ? this.selectedCoreAbatements : this.selectedApprovedAbatements;

        const hasSelectedChildren = allChildOptions
            .filter(opt => opt.label.startsWith(strategyLetter + '.'))
            .some(child => selectedChildren.includes(child.value));

        if (!hasSelectedChildren) {
            if (type === 'core') {
                this.selectedCoreStrategies = this.selectedCoreStrategies.filter(v => v !== parentValue);
            } else {
                this.selectedApprovedUses = this.selectedApprovedUses.filter(v => v !== parentValue);
            }
        }
    }

    handleStrategyFieldChange(event) {
        if (event.target.setCustomValidity) {
            event.target.setCustomValidity('');
        }

        const { field, strategy } = event.currentTarget.dataset;
        const value = event.target.value;
        if (!this.strategyData[strategy]) this.initializeStrategyFormData(strategy);
        this.strategyData[strategy][field] = value;
        this.notifyParentOfDataChange();
    }

    handlePersonnelFieldChange(event) {
        if (event.target.setCustomValidity) {
            event.target.setCustomValidity('');
        }

        const { field, strategy, id } = event.currentTarget.dataset;
        const value = event.target.value;
        if (!this.strategyResourcesData[strategy]) this.initializeStrategyFormData(strategy);
        const personnel = this.strategyResourcesData[strategy].personnel;
        const index = personnel.findIndex(p => p.id === id);
        if (index !== -1) personnel[index][field] = value;
        this.notifyParentOfDataChange();
    }

    handleBudgetFieldChange(event) {
        if (event.target.setCustomValidity) {
            event.target.setCustomValidity('');
        }

        const { field, strategy, id } = event.currentTarget.dataset;
        const value = event.target.value;
        if (!this.strategyResourcesData[strategy]) this.initializeStrategyFormData(strategy);
        const budget = this.strategyResourcesData[strategy].budget;
        const index = budget.findIndex(b => b.id === id);
        if (index !== -1) budget[index][field] = value;
        this.notifyParentOfDataChange();
    }

    handlePersonnelFieldChangeWithValidation(event) {
        this.handlePersonnelFieldChange(event);

        const { field, strategy } = event.currentTarget.dataset;
        if (field === 'total') {
            this.validateBudgetTotalsRealTime(strategy);
        }
    }

    handleBudgetFieldChangeWithValidation(event) {
        this.handleBudgetFieldChange(event);

        const { field, strategy } = event.currentTarget.dataset;
        if (field === 'total') {
            this.validateBudgetTotalsRealTime(strategy);
        }
    }

    handleStrategyFieldChangeWithValidation(event) {
        this.handleStrategyFieldChange(event);

        const { field, strategy } = event.currentTarget.dataset;
        if (field === 'budgetAmount') {
            this.validateBudgetTotalsRealTime(strategy);
        }
    }


    handleAddPersonnel(event) {
        const strategyValue = event.target.dataset.strategy;
        if (!this.strategyResourcesData[strategyValue]) {
            this.initializeStrategyFormData(strategyValue);
        }

        const personnelList = this.strategyResourcesData[strategyValue].personnel;
        const requiredFields = ['name', 'position', 'salary', 'effort', 'total'];

        if (!StrategyValidationUtil.validateRows(personnelList, requiredFields, 'personnel', this, strategyValue)) {
            return;
        }

        personnelList.push({
            id: this.generateId(),
            name: '',
            position: '',
            salary: '',
            effort: '',
            total: '',
            isRemovable: true
        });
        this.strategyResourcesData = { ...this.strategyResourcesData };
        this.notifyParentOfDataChange();
    }

    handleAddBudget(event) {
        const strategyValue = event.target.dataset.strategy;
        if (!this.strategyResourcesData[strategyValue]) {
            this.initializeStrategyFormData(strategyValue);
        }

        const budgetList = this.strategyResourcesData[strategyValue].budget;
        const requiredFields = ['item', 'purpose', 'calculation', 'total'];

        if (!StrategyValidationUtil.validateRows(budgetList, requiredFields, 'budget', this, strategyValue)) {
            return;
        }

        budgetList.push({
            id: this.generateId(),
            item: '',
            purpose: '',
            calculation: '',
            total: '',
            isRemovable: true
        });
        this.strategyResourcesData = { ...this.strategyResourcesData };
        this.notifyParentOfDataChange();
    }

    handleFieldFocus(event) {
        if (event.target.setCustomValidity) {
            event.target.setCustomValidity('');
        }
    }

    handleRemovePersonnel(event) {
        const { strategy, id } = event.target.dataset;
        if (this.strategyResourcesData[strategy]) {
            this.strategyResourcesData[strategy].personnel = this.strategyResourcesData[strategy].personnel.filter(p => p.id !== id);
            this.strategyResourcesData = { ...this.strategyResourcesData };
        }
        this.notifyParentOfDataChange();
    }

    handleRemoveBudget(event) {
        const { strategy, id } = event.target.dataset;
        if (this.strategyResourcesData[strategy]) {
            this.strategyResourcesData[strategy].budget = this.strategyResourcesData[strategy].budget.filter(b => b.id !== id);
            this.strategyResourcesData = { ...this.strategyResourcesData };
        }
        this.notifyParentOfDataChange();
    }

    @api
    validateAllFields() {
        const validationData = {
            selectedCoreAbatements: this.selectedCoreAbatements,
            selectedApprovedAbatements: this.selectedApprovedAbatements,
            strategyData: this.strategyData,
            strategyResourcesData: this.strategyResourcesData,
            coreAbatementStrategyOptions: this.coreAbatementStrategyOptions,
            approvedAbatementStrategyOptions: this.approvedAbatementStrategyOptions
        };

        return StrategyValidationUtil.validateAllFields(validationData, this);
    }

    validateBudgetTotalsRealTime(strategyValue) {
        const validation = StrategyValidationUtil.validateBudgetTotalsRealTime(
            strategyValue,
            this.strategyData,
            this.strategyResourcesData,
            this.coreAbatementStrategyOptions,
            this.approvedAbatementStrategyOptions
        );

        if (validation.hasWarning) {
            console.warn(`Budget mismatch for ${validation.strategyLabel}: Budget Amount: ${validation.budgetAmount.toFixed(2)}, Total Charges: ${validation.totalCharges.toFixed(2)}`);
            this.addBudgetMismatchIndicator(strategyValue, validation.budgetAmount, validation.totalCharges);
        } else {
            this.removeBudgetMismatchIndicator(strategyValue);
        }
    }

    addBudgetMismatchIndicator(strategyValue, budgetAmount, totalCharges) {
        const formContainer = this.template.querySelector(`[data-strategy="${strategyValue}"] .strategy-form-container`);

        if (formContainer) {
            const existing = formContainer.querySelector('.budget-mismatch-warning');
            if (existing) {
                existing.remove();
            }

            const warningDiv = document.createElement('div');
            warningDiv.className = 'budget-mismatch-warning slds-box slds-theme_warning slds-m-top_small';
            warningDiv.innerHTML = `
            <div class="slds-text-color_error slds-text-heading_small">
                Budget Mismatch: 
                Budget Amount: ${budgetAmount.toFixed(2)} | 
                Total Charges: ${totalCharges.toFixed(2)} | 
                Difference: ${Math.abs(budgetAmount - totalCharges).toFixed(2)}
            </div>
        `;

            const budgetAmountField = formContainer.querySelector('[data-field="budgetAmount"]');
            if (budgetAmountField && budgetAmountField.parentNode) {
                budgetAmountField.parentNode.insertAdjacentElement('afterend', warningDiv);
            }
        }
    }

    removeBudgetMismatchIndicator(strategyValue) {
        const formContainer = this.template.querySelector(`[data-strategy="${strategyValue}"] .strategy-form-container`);

        if (formContainer) {
            const existing = formContainer.querySelector('.budget-mismatch-warning');
            if (existing) {
                existing.remove();
            }
        }
    }

    getStrategyFormData(strategyValue) {
        return this.strategyData[strategyValue] || {
            budgetAmount: '',
            isInitialContinuation: '',
            budgetNarrative: '',
            implementationPlan: '',
            outcomeMeasures: '',
            processMeasures: ''
        };
    }

    getPersonnelData(strategyValue) {
        const personnelArray = this.strategyResourcesData[strategyValue]?.personnel || [];
        return personnelArray.map((personnelItem, index) => {
            return {
                ...personnelItem,
                isRemovable: index > 0
            };
        });
    }

    getBudgetData(strategyValue) {
        const budgetArray = this.strategyResourcesData[strategyValue]?.budget || [];
        return budgetArray.map((budgetItem, index) => {
            return {
                ...budgetItem,
                isRemovable: index > 0
            };
        });
    }

    generateId() { return Date.now().toString(36) + Math.random().toString(36).substring(2); }
    splitString(value) { return value ? value.split(';') : []; }

    initializeStrategyFormData(strategyValue) {
        if (!this.strategyData[strategyValue]) {
            this.strategyData[strategyValue] = {
                budgetAmount: '',
                isInitialContinuation: '',
                budgetNarrative: '',
                implementationPlan: '',
                outcomeMeasures: '',
                processMeasures: ''
            };
        }
        if (!this.strategyResourcesData[strategyValue]) {
            this.strategyResourcesData[strategyValue] = {
                personnel: [{ id: this.generateId(), name: '', position: '', salary: '', effort: '', total: '' }],
                budget: [{ id: this.generateId(), item: '', purpose: '', calculation: '', total: '' }]
            };
        }
    }

    clearStrategyFormData(strategyValue) {
        delete this.strategyData[strategyValue];
        delete this.strategyResourcesData[strategyValue];
    }

    @api
    getCurrentStrategiesData() {
        return {
            selectedCoreStrategies: [...this.selectedCoreStrategies],
            selectedCoreAbatements: [...this.selectedCoreAbatements],
            expandedCoreStrategies: [...this.expandedCoreStrategies],
            selectedApprovedUses: [...this.selectedApprovedUses],
            selectedApprovedAbatements: [...this.selectedApprovedAbatements],
            expandedApprovedUses: [...this.expandedApprovedUses],
            strategyData: { ...this.strategyData },
            strategyResourcesData: { ...this.strategyResourcesData },
        };
    }

    @api
    loadStrategiesData(data) {
        if (data) {
            console.log('Loading strategies data:', data);

            this.strategyData = data.strategyData || {};
            this.strategyResourcesData = data.strategyResourcesData || {};
            this.selectedCoreStrategies = data.selectedCoreStrategies || [];
            this.selectedCoreAbatements = data.selectedCoreAbatements || [];
            this.expandedCoreStrategies = data.expandedCoreStrategies || [...this.selectedCoreStrategies];
            this.selectedApprovedUses = data.selectedApprovedUses || [];
            this.selectedApprovedAbatements = data.selectedApprovedAbatements || [];
            this.expandedApprovedUses = data.expandedApprovedUses || [...this.selectedApprovedUses];
        } else {
            Object.assign(this, {
                strategyData: {},
                strategyResourcesData: {},
                selectedCoreStrategies: [],
                selectedCoreAbatements: [],
                expandedCoreStrategies: [],
                selectedApprovedUses: [],
                selectedApprovedAbatements: [],
                expandedApprovedUses: []
            });
        }
    }

    notifyParentOfDataChange() {
        this.dispatchEvent(new CustomEvent('datachange', {
            detail: this.getCurrentStrategiesData(),
            bubbles: true,
            composed: true
        }));
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}