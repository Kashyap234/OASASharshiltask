/**
 * Centralized state management for GPS Application Form
 * Handles all application state and provides reactive updates
 */
export class GPSApplicationState {
    constructor() {
        this.reset();
        this.listeners = new Map();
    }

    /**
     * Reset state to initial values
     */
    reset() {
        this._state = {
            // Application metadata
            applicationId: null,
            isExistingApplication: false,
            originalApplicationStatus: null,
            hasDataLoaded: false,
            
            // Form data
            formData: {},
            
            // UI state
            currentStep: 1,
            totalSteps: 4,
            isLoading: false,
            
            // Validation
            errors: {},
            isStepValid: false,
            
            // Files
            uploadedFiles: [],
            
            // Partners
            partners: [],
            currentPartnerData: {},
            isCurrentPartnerValid: false,
            currentPartnerIndex: 0,
            isEditingExistingPartner: false,
            activePartnerData: {},
            isWorkingWithPartner: false,
            
            // Strategies
            strategiesData: {},
            currentStrategiesPartnerId: null
        };
    }

    /**
     * Get current state
     */
    getState() {
        return { ...this._state };
    }

    /**
     * Update state and notify listeners
     * @param {Object} updates - State updates
     */
    updateState(updates) {
        const previousState = { ...this._state };
        this._state = { ...this._state, ...updates };
        
        // Notify listeners of state changes
        this.notifyListeners(previousState, this._state);
    }

    /**
     * Subscribe to state changes
     * @param {String} listenerId - Unique listener ID
     * @param {Function} callback - Callback function
     */
    subscribe(listenerId, callback) {
        this.listeners.set(listenerId, callback);
    }

    /**
     * Unsubscribe from state changes
     * @param {String} listenerId - Listener ID to remove
     */
    unsubscribe(listenerId) {
        this.listeners.delete(listenerId);
    }

    /**
     * Notify all listeners of state changes
     * @param {Object} previousState - Previous state
     * @param {Object} newState - New state
     */
    notifyListeners(previousState, newState) {
        this.listeners.forEach(callback => {
            try {
                callback(newState, previousState);
            } catch (error) {
                console.error('Error in state listener:', error);
            }
        });
    }

    // Getters for computed properties
    get isStep1() { return this._state.currentStep === 1; }
    get isStep2() { return this._state.currentStep === 2; }
    get isStep3() { return this._state.currentStep === 3; }
    get isStep4() { return this._state.currentStep === 4; }
    get isFirstStep() { return this._state.currentStep === 1; }
    get isLastStep() { return this._state.currentStep === this._state.totalSteps; }
    get isStep3OrLater() { return this._state.currentStep >= 3; }
    get progressPercentage() { return (this._state.currentStep / this._state.totalSteps) * 100; }
    get partnersCount() { return this._state.partners.length; }
    get hasPartners() { return this._state.partners.length > 0; }
    get hasActivePartner() { 
        return this._state.activePartnerData && Object.keys(this._state.activePartnerData).length > 0; 
    }

    get currentPartnerNumber() {
        return this._state.isEditingExistingPartner || 
               (this._state.activePartnerData && this._state.activePartnerData.Id)
            ? this._state.activePartnerData.Id
            : this._state.partners.length + 1;
    }

    get isExistingDraft() { 
        return this._state.isExistingApplication && this._state.originalApplicationStatus === 'Draft'; 
    }
    
    get isExistingSubmitted() { 
        return this._state.isExistingApplication && this._state.originalApplicationStatus === 'Submitted'; 
    }
    
    get formTitle() {
        if (this.isExistingSubmitted) {
            return 'View Submitted Application';
        } else if (this.isExistingDraft) {
            return 'Edit Draft Application';
        } else {
            return 'New GPS Funding Application';
        }
    }
    
    get isFormDisabled() {
        return this.isExistingSubmitted; 
    }
    
    get submitButtonLabel() {
        return this._state.isExistingApplication ? 'Update and Submit' : 'Submit Application';
    }
    
    get draftButtonLabel() {
        return this._state.isExistingApplication ? 'Update Draft' : 'Save as Draft';
    }

    get canProceedFromStep2() { 
        return this._state.partners.length > 0 || this._state.isCurrentPartnerValid; 
    }

    get stepTwoTitle() { 
        return this._state.isEditingExistingPartner ? 'Edit Partner Information' : 'Add Partner Information'; 
    }

    // State manipulation methods
    
    /**
     * Initialize application state
     * @param {String} applicationId - Application ID from URL
     * @param {Object} userData - Current user data
     */
    initializeApplication(applicationId, userData) {
        this.updateState({
            applicationId,
            isExistingApplication: !!applicationId,
            formData: applicationId ? {} : {
                Name_of_Person_Completing_Form__c: userData?.Name || '',
                Date__c: new Date().toISOString().split('T')[0],
                Application_Status__c: 'Draft'
            }
        });
    }

    /**
     * Load existing application data
     * @param {Object} applicationData - Application data from server
     */
    loadApplicationData(applicationData) {
        const updates = {
            formData: { ...applicationData },
            originalApplicationStatus: applicationData.Application_Status__c,
            hasDataLoaded: true
        };

        if (applicationData.UploadedFiles && Array.isArray(applicationData.UploadedFiles)) {
            updates.uploadedFiles = [...applicationData.UploadedFiles];
        }

        if (applicationData.Partners && Array.isArray(applicationData.Partners)) {
            updates.partners = [...applicationData.Partners];
            
            if (applicationData.Partners.length > 0) {
                updates.activePartnerData = { ...applicationData.Partners[0] };
                updates.strategiesData = applicationData.Partners[0].strategiesData || {};
                updates.currentStrategiesPartnerId = applicationData.Partners[0].Id;
                updates.isWorkingWithPartner = true;
            }
        }

        this.updateState(updates);
    }

    /**
     * Update form field
     * @param {String} fieldName - Field name
     * @param {*} value - Field value
     */
    updateFormField(fieldName, value) {
        this.updateState({
            formData: {
                ...this._state.formData,
                [fieldName]: value
            }
        });
    }

    /**
     * Add partner to application
     * @param {Object} partnerData - Partner data
     */
    addPartner(partnerData) {
        const newPartner = { ...partnerData, Id: this._state.partners.length + 1 };
        this.updateState({
            partners: [...this._state.partners, newPartner],
            currentPartnerData: {},
            isCurrentPartnerValid: false,
            isEditingExistingPartner: false
        });
    }

    /**
     * Update partner data
     * @param {Number} partnerId - Partner ID
     * @param {Object} partnerData - Updated partner data
     */
    updatePartner(partnerId, partnerData) {
        const updatedPartners = this._state.partners.map(partner => 
            partner.Id === partnerId ? { ...partner, ...partnerData } : partner
        );
        
        this.updateState({
            partners: updatedPartners,
            activePartnerData: this._state.activePartnerData.Id === partnerId 
                ? { ...this._state.activePartnerData, ...partnerData }
                : this._state.activePartnerData
        });
    }

    /**
     * Remove partner from application
     * @param {Number} partnerId - Partner ID to remove
     */
    removePartner(partnerId) {
        const updatedPartners = this._state.partners.filter(partner => partner.Id !== partnerId);
        
        this.updateState({
            partners: updatedPartners,
            activePartnerData: this._state.activePartnerData.Id === partnerId ? {} : this._state.activePartnerData,
            isWorkingWithPartner: updatedPartners.length > 0
        });
    }

    /**
     * Navigate to next step
     */
    nextStep() {
        if (this._state.currentStep < this._state.totalSteps) {
            this.updateState({
                currentStep: this._state.currentStep + 1
            });
        }
    }

    /**
     * Navigate to previous step
     */
    previousStep() {
        if (this._state.currentStep > 1) {
            this.updateState({
                currentStep: this._state.currentStep - 1
            });
        }
    }

    /**
     * Set loading state
     * @param {Boolean} isLoading - Loading state
     */
    setLoading(isLoading) {
        this.updateState({ isLoading });
    }

    /**
     * Set validation errors
     * @param {Object} errors - Validation errors
     */
    setErrors(errors) {
        this.updateState({ errors });
    }

    /**
     * Clear all errors
     */
    clearErrors() {
        this.updateState({ errors: {} });
    }
}