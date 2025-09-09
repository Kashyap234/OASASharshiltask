import { LightningElement, api, track } from 'lwc';

export default class GPSformStepFour extends LightningElement {
    @api formData = {};
    @track totalBudget = 0;
    @api totalAmountRequested = 0;
    @api isFormDisabled = false;
    @api partners = [];


    handleInputChange(event) {
        const { name, value, type, checked } = event.target;
        const detailValue = type === 'checkbox' ? checked : value;

        this.dispatchEvent(new CustomEvent('inputchange', {
            detail: {
                name: name,
                value: detailValue
            }
        }));
    }

    connectedCallback() {
        // console.log('Total Budget: ', this.calculateTotalBudget());
        
        // set 100 delay
        setTimeout(() => {
            this.totalBudget = this.calculateTotalBudget();
        }, 100);
        // this.totalBudget = this.calculateTotalBudget();
    }

    @api
    validateStep() {
        const allInputs = this.template.querySelectorAll('lightning-input');
        let allValid = true;

        allInputs.forEach(input => {
            if (!input.reportValidity()) {
                allValid = false;
            }
        });

        return allValid;
    }

    calculateTotalBudget() {
        var total = 0;

        console.log('Calculating total budget...');
        console.log('Partners data: ', JSON.stringify(this.partners, null, 2));
        
        
        if (this.partners && Array.isArray(this.partners)) {
            this.partners.forEach(partner => {
                if (partner.strategiesData && partner.strategiesData.strategyData) {
                    const strategies = Object.values(partner.strategiesData.strategyData);
                    strategies.forEach(strategy => {
                        console.log('Strategy data: ', JSON.stringify(strategy, null, 2));
                        if (strategy && typeof strategy.budgetAmount === 'number') {
                            total += strategy.budgetAmount;
                        } else {
                            //convert to number if it's a string
                            const budgetAmount = parseFloat(strategy.budgetAmount);
                            if (!isNaN(budgetAmount)) {
                                total += budgetAmount;
                            }
                        }
                        console.log('Current total after strategy: ', total);
                    });
                }
            });
        }        

        this.dispatchEvent(new CustomEvent('inputchange', {
            detail: {
                name: 'Total_Project_Budget__c',
                value: total
            }
        }));

        return total;
    }
}