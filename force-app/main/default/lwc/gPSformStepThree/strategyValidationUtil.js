export default class StrategyValidationUtil {
    static validateAllFields(validationData, component) {
        const {
            selectedCoreAbatements,
            selectedApprovedAbatements,
            strategyData,
            strategyResourcesData,
            coreAbatementStrategyOptions,
            approvedAbatementStrategyOptions
        } = validationData;

        const validationResults = {
            isValid: true,
            errors: []
        };

        this.clearAllCustomValidity(component);

        if (selectedCoreAbatements.length === 0 && selectedApprovedAbatements.length === 0) {
            validationResults.isValid = false;
            validationResults.errors.push('Please select at least one Core Strategy or Approved Use strategy.');
            component.showToast('Validation Error', 'Please select at least one strategy before proceeding.', 'error');
            return validationResults;
        }

        const coreValidation = this.validateStrategiesSection(
            selectedCoreAbatements,
            'Core Strategy',
            strategyData,
            strategyResourcesData,
            coreAbatementStrategyOptions,
            component
        );
        if (!coreValidation.isValid) {
            validationResults.isValid = false;
            validationResults.errors.push(...coreValidation.errors);
        }

        const approvedValidation = this.validateStrategiesSection(
            selectedApprovedAbatements,
            'Approved Use',
            strategyData,
            strategyResourcesData,
            approvedAbatementStrategyOptions,
            component
        );
        if (!approvedValidation.isValid) {
            validationResults.isValid = false;
            validationResults.errors.push(...approvedValidation.errors);
        }

        if (validationResults.isValid) {
            component.showToast('Validation Success', 'All fields are properly filled out.', 'success');
        }

        return validationResults;
    }

    static validateStrategiesSection(selectedStrategies, sectionName, strategyData, strategyResourcesData, strategyOptions, component) {
        const validationResult = {
            isValid: true,
            errors: []
        };

        selectedStrategies.forEach(strategyValue => {
            const strategyLabel = this.getStrategyLabel(strategyValue, strategyOptions);

            const strategyFormValidation = this.validateStrategyForm(
                strategyValue,
                strategyLabel,
                sectionName,
                strategyData,
                strategyResourcesData,
                component
            );
            if (!strategyFormValidation.isValid) {
                validationResult.isValid = false;
                validationResult.errors.push(...strategyFormValidation.errors);
            }

            const personnelValidation = this.validatePersonnelData(
                strategyValue,
                strategyLabel,
                sectionName,
                strategyResourcesData,
                component
            );
            if (!personnelValidation.isValid) {
                validationResult.isValid = false;
                validationResult.errors.push(...personnelValidation.errors);
            }

            const budgetValidation = this.validateBudgetData(
                strategyValue,
                strategyLabel,
                sectionName,
                strategyResourcesData,
                component
            );
            if (!budgetValidation.isValid) {
                validationResult.isValid = false;
                validationResult.errors.push(...budgetValidation.errors);
            }
        });

        return validationResult;
    }

    static validateStrategyForm(strategyValue, strategyLabel, sectionName, strategyData, strategyResourcesData, component) {
        const validationResult = {
            isValid: true,
            errors: []
        };

        const currentStrategyData = strategyData[strategyValue];

        if (!currentStrategyData) {
            validationResult.isValid = false;
            validationResult.errors.push(`${sectionName} "${strategyLabel}": Strategy form data is missing.`);
            return validationResult;
        }

        const requiredFields = [
            { field: 'budgetAmount', label: 'Budget Amount', selector: `[data-strategy="${strategyValue}"][data-field="budgetAmount"]` },
            { field: 'isInitialContinuation', label: 'Initial/Continuation', selector: `[data-strategy="${strategyValue}"][data-field="isInitialContinuation"]` },
            { field: 'budgetNarrative', label: 'Budget Narrative', selector: `[data-strategy="${strategyValue}"][data-field="budgetNarrative"]` },
            { field: 'implementationPlan', label: 'Implementation Plan', selector: `[data-strategy="${strategyValue}"][data-field="implementationPlan"]` },
            { field: 'outcomeMeasures', label: 'Outcome Measures', selector: `[data-strategy="${strategyValue}"][data-field="outcomeMeasures"]` },
            { field: 'processMeasures', label: 'Process Measures', selector: `[data-strategy="${strategyValue}"][data-field="processMeasures"]` }
        ];

        requiredFields.forEach(({ field, label, selector }) => {
            if (!currentStrategyData[field] || currentStrategyData[field].toString().trim() === '') {
                validationResult.isValid = false;
                validationResult.errors.push(`${sectionName} "${strategyLabel}": ${label} is required.`);

                const fieldElement = component.template.querySelector(selector);
                if (fieldElement) {
                    fieldElement.setCustomValidity(`${label} is required`);
                    fieldElement.reportValidity();
                }
            }
        });

        if (currentStrategyData.budgetAmount) {
            const budgetAmount = parseFloat(currentStrategyData.budgetAmount);
            if (isNaN(budgetAmount) || budgetAmount <= 0) {
                validationResult.isValid = false;
                validationResult.errors.push(`${sectionName} "${strategyLabel}": Budget Amount must be a positive number.`);

                const budgetField = component.template.querySelector(`[data-strategy="${strategyValue}"][data-field="budgetAmount"]`);
                if (budgetField) {
                    budgetField.setCustomValidity('Budget Amount must be a positive number');
                    budgetField.reportValidity();
                }
            } else {
                const budgetValidation = this.validateBudgetAmountTotal(
                    strategyValue,
                    strategyLabel,
                    sectionName,
                    budgetAmount,
                    strategyResourcesData,
                    component
                );
                if (!budgetValidation.isValid) {
                    validationResult.isValid = false;
                    validationResult.errors.push(...budgetValidation.errors);
                }
            }
        }

        return validationResult;
    }

    static validatePersonnelData(strategyValue, strategyLabel, sectionName, strategyResourcesData, component) {
        const validationResult = {
            isValid: true,
            errors: []
        };

        const resourcesData = strategyResourcesData[strategyValue];

        if (!resourcesData || !resourcesData.personnel || resourcesData.personnel.length === 0) {
            validationResult.isValid = false;
            validationResult.errors.push(`${sectionName} "${strategyLabel}": At least one personnel entry is required.`);
            return validationResult;
        }

        const requiredPersonnelFields = [
            { field: 'name', label: 'Name' },
            { field: 'position', label: 'Position' },
            { field: 'salary', label: 'Annual Salary' },
            { field: 'effort', label: 'Level of Effort' },
            { field: 'total', label: 'Total Charged' }
        ];

        resourcesData.personnel.forEach((personnel, index) => {
            requiredPersonnelFields.forEach(({ field, label }) => {
                if (!personnel[field] || personnel[field].toString().trim() === '') {
                    validationResult.isValid = false;
                    validationResult.errors.push(`${sectionName} "${strategyLabel}": Personnel row ${index + 1} - ${label} is required.`);

                    const fieldElement = component.template.querySelector(`[data-strategy="${strategyValue}"][data-field="${field}"][data-id="${personnel.id}"]`);
                    if (fieldElement) {
                        fieldElement.setCustomValidity(`${label} is required`);
                        fieldElement.reportValidity();
                    }
                }
            });

            if (personnel.salary) {
                const salary = parseFloat(personnel.salary);
                if (isNaN(salary) || salary <= 0) {
                    validationResult.isValid = false;
                    validationResult.errors.push(`${sectionName} "${strategyLabel}": Personnel row ${index + 1} - Annual Salary must be a positive number.`);

                    const salaryField = component.template.querySelector(`[data-strategy="${strategyValue}"][data-field="salary"][data-id="${personnel.id}"]`);
                    if (salaryField) {
                        salaryField.setCustomValidity('Annual Salary must be a positive number');
                        salaryField.reportValidity();
                    }
                }
            }

            if (personnel.total) {
                const total = parseFloat(personnel.total);
                if (isNaN(total) || total <= 0) {
                    validationResult.isValid = false;
                    validationResult.errors.push(`${sectionName} "${strategyLabel}": Personnel row ${index + 1} - Total Charged must be a positive number.`);

                    const totalField = component.template.querySelector(`[data-strategy="${strategyValue}"][data-field="total"][data-id="${personnel.id}"]`);
                    if (totalField) {
                        totalField.setCustomValidity('Total Charged must be a positive number');
                        totalField.reportValidity();
                    }
                }
            }
        });

        return validationResult;
    }

    static validateBudgetData(strategyValue, strategyLabel, sectionName, strategyResourcesData, component) {
        const validationResult = {
            isValid: true,
            errors: []
        };

        const resourcesData = strategyResourcesData[strategyValue];

        if (!resourcesData || !resourcesData.budget || resourcesData.budget.length === 0) {
            validationResult.isValid = false;
            validationResult.errors.push(`${sectionName} "${strategyLabel}": At least one budget entry is required.`);
            return validationResult;
        }

        const requiredBudgetFields = [
            { field: 'item', label: 'Item' },
            { field: 'purpose', label: 'Purpose' },
            { field: 'calculation', label: 'Calculation' },
            { field: 'total', label: 'Total Charged' }
        ];

        resourcesData.budget.forEach((budget, index) => {
            requiredBudgetFields.forEach(({ field, label }) => {
                if (!budget[field] || budget[field].toString().trim() === '') {
                    validationResult.isValid = false;
                    validationResult.errors.push(`${sectionName} "${strategyLabel}": Budget row ${index + 1} - ${label} is required.`);

                    const fieldElement = component.template.querySelector(`[data-strategy="${strategyValue}"][data-field="${field}"][data-id="${budget.id}"]`);
                    if (fieldElement) {
                        fieldElement.setCustomValidity(`${label} is required`);
                        fieldElement.reportValidity();
                    }
                }
            });

            if (budget.total) {
                const total = parseFloat(budget.total);
                if (isNaN(total) || total <= 0) {
                    validationResult.isValid = false;
                    validationResult.errors.push(`${sectionName} "${strategyLabel}": Budget row ${index + 1} - Total Charged must be a positive number.`);

                    const totalField = component.template.querySelector(`[data-strategy="${strategyValue}"][data-field="total"][data-id="${budget.id}"]`);
                    if (totalField) {
                        totalField.setCustomValidity('Total Charged must be a positive number');
                        totalField.reportValidity();
                    }
                }
            }
        });

        return validationResult;
    }

    static validateBudgetAmountTotal(strategyValue, strategyLabel, sectionName, budgetAmount, strategyResourcesData, component) {
        const validationResult = {
            isValid: true,
            errors: []
        };

        const resourcesData = strategyResourcesData[strategyValue];

        if (!resourcesData) {
            validationResult.isValid = false;
            validationResult.errors.push(`${sectionName} "${strategyLabel}": Personnel and Budget data is missing.`);
            return validationResult;
        }

        const totals = this.calculateCurrentTotals(strategyValue, strategyResourcesData);
        const difference = Math.abs(totals.grandTotal - budgetAmount);

        if (difference > 0.01) {
            validationResult.isValid = false;
            const errorMessage = `Budget Amount (${budgetAmount.toFixed(2)}) must equal the sum of Personnel Total Charged (${totals.personnelTotal.toFixed(2)}) + Budget Total Charged (${totals.budgetTotal.toFixed(2)}) = ${totals.grandTotal.toFixed(2)}. Difference: ${difference.toFixed(2)}`;
            validationResult.errors.push(`${sectionName} "${strategyLabel}": ${errorMessage}`);

            const budgetField = component.template.querySelector(`[data-strategy="${strategyValue}"][data-field="budgetAmount"]`);
            if (budgetField) {
                budgetField.setCustomValidity(errorMessage);
                budgetField.reportValidity();
            }
        }

        return validationResult;
    }

    static validateRows(rows, fieldsToValidate, rowType = 'row', component, strategyValue) {
        for (let i = 0; i < rows.length; i++) {
            const row = rows[i];
            for (const field of fieldsToValidate) {
                if (!row[field] || row[field].toString().trim() === '') {
                    const fieldElement = component.template.querySelector(`[data-strategy="${strategyValue}"][data-field="${field}"][data-id="${row.id}"]`);
                    if (fieldElement) {
                        fieldElement.setCustomValidity(`${this.getFieldLabel(field)} is required`);
                        fieldElement.reportValidity();
                        fieldElement.focus();
                    }
                    return false;
                }
            }

            if (rowType === 'personnel') {
                const salary = parseFloat(row.salary);
                const total = parseFloat(row.total);

                if (row.salary && (isNaN(salary) || salary <= 0)) {
                    const salaryField = component.template.querySelector(`[data-strategy="${strategyValue}"][data-field="salary"][data-id="${row.id}"]`);
                    if (salaryField) {
                        salaryField.setCustomValidity('Annual Salary must be a positive number');
                        salaryField.reportValidity();
                        salaryField.focus();
                    }
                    return false;
                }

                if (row.total && (isNaN(total) || total <= 0)) {
                    const totalField = component.template.querySelector(`[data-strategy="${strategyValue}"][data-field="total"][data-id="${row.id}"]`);
                    if (totalField) {
                        totalField.setCustomValidity('Total Charged must be a positive number');
                        totalField.reportValidity();
                        totalField.focus();
                    }
                    return false;
                }
            }

            if (rowType === 'budget') {
                const total = parseFloat(row.total);

                if (row.total && (isNaN(total) || total <= 0)) {
                    const totalField = component.template.querySelector(`[data-strategy="${strategyValue}"][data-field="total"][data-id="${row.id}"]`);
                    if (totalField) {
                        totalField.setCustomValidity('Total Charged must be a positive number');
                        totalField.reportValidity();
                        totalField.focus();
                    }
                    return false;
                }
            }
        }
        return true;
    }

    static clearAllCustomValidity(component) {
        const allInputs = component.template.querySelectorAll('lightning-input, lightning-textarea, lightning-combobox');
        allInputs.forEach(input => {
            if (input.setCustomValidity) {
                input.setCustomValidity('');
            }
        });
    }

    static getFieldLabel(field) {
        const fieldLabels = {
            'name': 'Name',
            'position': 'Position',
            'salary': 'Annual Salary',
            'effort': 'Level of Effort',
            'total': 'Total Charged',
            'item': 'Item',
            'purpose': 'Purpose',
            'calculation': 'Calculation'
        };
        return fieldLabels[field] || field;
    }

    static validateBudgetTotalsRealTime(strategyValue, strategyData, strategyResourcesData, coreAbatementStrategyOptions, approvedAbatementStrategyOptions) {
        const currentStrategyData = strategyData[strategyValue];

        if (!currentStrategyData || !currentStrategyData.budgetAmount) {
            return { hasWarning: false };
        }

        const budgetAmount = parseFloat(currentStrategyData.budgetAmount);
        if (isNaN(budgetAmount) || budgetAmount <= 0) {
            return { hasWarning: false };
        }

        const totals = this.calculateCurrentTotals(strategyValue, strategyResourcesData);
        const difference = Math.abs(totals.grandTotal - budgetAmount);

        if (difference > 0.01) {
            const strategyLabel = this.getStrategyLabel(strategyValue, coreAbatementStrategyOptions, approvedAbatementStrategyOptions);

            return {
                hasWarning: true,
                strategyLabel,
                budgetAmount,
                totalCharges: totals.grandTotal,
                difference,
                personnelTotal: totals.personnelTotal,
                budgetTotal: totals.budgetTotal
            };
        }

        return { hasWarning: false };
    }

    static calculateCurrentTotals(strategyValue, strategyResourcesData) {
        const resourcesData = strategyResourcesData[strategyValue];

        if (!resourcesData) {
            return {
                personnelTotal: 0,
                budgetTotal: 0,
                grandTotal: 0
            };
        }

        const personnelTotal = resourcesData.personnel ?
            resourcesData.personnel.reduce((sum, personnel) => sum + (parseFloat(personnel.total) || 0), 0) : 0;

        const budgetTotal = resourcesData.budget ?
            resourcesData.budget.reduce((sum, budget) => sum + (parseFloat(budget.total) || 0), 0) : 0;

        return {
            personnelTotal,
            budgetTotal,
            grandTotal: personnelTotal + budgetTotal
        };
    }

    static getStrategyLabel(strategyValue, coreAbatementStrategyOptions, approvedAbatementStrategyOptions) {
        let strategy = coreAbatementStrategyOptions?.find(opt => opt.value === strategyValue);

        if (!strategy && approvedAbatementStrategyOptions) {
            strategy = approvedAbatementStrategyOptions.find(opt => opt.value === strategyValue);
        }

        return strategy ? strategy.label : strategyValue;
    }
}