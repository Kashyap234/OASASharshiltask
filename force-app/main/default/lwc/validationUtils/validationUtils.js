/**
 * Validation utilities for GPS Application Form
 * Contains validation functions for various field types
 */

export class ValidationUtils {
    
    /**
     * Validate email format
     * @param {string} email - Email to validate
     * @returns {object} - {isValid: boolean, message: string}
     */
    static validateEmail(email) {
        if (!email) {
            return { isValid: false, message: 'Email is required' };
        }
        
        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        if (!emailRegex.test(email)) {
            return { isValid: false, message: 'Please enter a valid email address' };
        }
        
        if (email.length > 254) {
            return { isValid: false, message: 'Email address is too long' };
        }
        
        return { isValid: true, message: '' };
    }
    
    /**
     * Validate phone number format
     * @param {string} phone - Phone number to validate
     * @returns {object} - {isValid: boolean, message: string}
     */
    static validatePhone(phone) {
        if (!phone) {
            return { isValid: true, message: '' }; // Phone is optional in most cases
        }
        
        // Remove all non-digit characters
        const cleanPhone = phone.replace(/\D/g, '');
        
        // Check if it's a valid US phone number (10 digits)
        if (cleanPhone.length !== 10) {
            return { isValid: false, message: 'Please enter a valid 10-digit phone number' };
        }
        
        // Check if it starts with valid area code (not 0 or 1)
        if (cleanPhone.charAt(0) === '0' || cleanPhone.charAt(0) === '1') {
            return { isValid: false, message: 'Area code cannot start with 0 or 1' };
        }
        
        return { isValid: true, message: '' };
    }
    
    /**
     * Validate ZIP code format
     * @param {string} zip - ZIP code to validate
     * @returns {object} - {isValid: boolean, message: string}
     */
    static validateZip(zip) {
        if (!zip) {
            return { isValid: false, message: 'ZIP code is required' };
        }
        
        // US ZIP code format: 5 digits or 5+4 digits
        const zipRegex = /^\d{5}(-\d{4})?$/;
        if (!zipRegex.test(zip)) {
            return { isValid: false, message: 'Please enter a valid ZIP code (12345 or 12345-6789)' };
        }
        
        return { isValid: true, message: '' };
    }
    
    /**
     * Validate required text field
     * @param {string} value - Value to validate
     * @param {string} fieldName - Name of the field for error message
     * @param {number} minLength - Minimum length (optional)
     * @param {number} maxLength - Maximum length (optional)
     * @returns {object} - {isValid: boolean, message: string}
     */
    static validateRequired(value, fieldName, minLength = 0, maxLength = 255) {
        if (!value || value.trim().length === 0) {
            return { isValid: false, message: `${fieldName} is required` };
        }
        
        const trimmedValue = value.trim();
        
        if (trimmedValue.length < minLength) {
            return { isValid: false, message: `${fieldName} must be at least ${minLength} characters` };
        }
        
        if (trimmedValue.length > maxLength) {
            return { isValid: false, message: `${fieldName} cannot exceed ${maxLength} characters` };
        }
        
        return { isValid: true, message: '' };
    }
    
    /**
     * Validate text field with special characters check
     * @param {string} value - Value to validate
     * @param {string} fieldName - Name of the field for error message
     * @param {boolean} allowSpecialChars - Whether to allow special characters
     * @returns {object} - {isValid: boolean, message: string}
     */
    static validateText(value, fieldName, allowSpecialChars = true) {
        if (!value) {
            return { isValid: true, message: '' }; // Optional field
        }
        
        if (!allowSpecialChars) {
            const alphanumericRegex = /^[a-zA-Z0-9\s]+$/;
            if (!alphanumericRegex.test(value)) {
                return { isValid: false, message: `${fieldName} can only contain letters, numbers, and spaces` };
            }
        }
        
        return { isValid: true, message: '' };
    }
    
    /**
     * Validate SCEIS Vendor Number format
     * @param {string} vendorNumber - Vendor number to validate
     * @returns {object} - {isValid: boolean, message: string}
     */
    static validateVendorNumber(vendorNumber) {
        // if (!vendorNumber) {
        //     return { isValid: true, message: '' }; // Optional field
        // }
        
        // // Assuming SCEIS vendor number format (adjust as needed)
        // const vendorRegex = /^[A-Z0-9]{6,10}$/;
        // if (!vendorRegex.test(vendorNumber)) {
        //     return { isValid: false, message: 'Please enter a valid SCEIS Vendor Number (6-10 alphanumeric characters)' };
        // }
        
        return { isValid: true, message: '' };
    }
    
    /**
     * Validate address line
     * @param {string} address - Address to validate
     * @param {string} fieldName - Name of the field for error message
     * @param {boolean} required - Whether the field is required
     * @returns {object} - {isValid: boolean, message: string}
     */
    static validateAddress(address, fieldName, required = false) {
        if (!address || address.trim().length === 0) {
            if (required) {
                return { isValid: false, message: `${fieldName} is required` };
            }
            return { isValid: true, message: '' };
        }
        
        const trimmedAddress = address.trim();
        
        if (trimmedAddress.length < 3) {
            return { isValid: false, message: `${fieldName} must be at least 3 characters` };
        }
        
        if (trimmedAddress.length > 100) {
            return { isValid: false, message: `${fieldName} cannot exceed 100 characters` };
        }
        
        return { isValid: true, message: '' };
    }
    
    /**
     * Validate city name
     * @param {string} city - City name to validate
     * @returns {object} - {isValid: boolean, message: string}
     */
    static validateCity(city) {
        if (!city || city.trim().length === 0) {
            return { isValid: false, message: 'City is required' };
        }
        
        const trimmedCity = city.trim();
        
        // City names should only contain letters, spaces, hyphens, and apostrophes
        const cityRegex = /^[a-zA-Z\s\-']+$/;
        if (!cityRegex.test(trimmedCity)) {
            return { isValid: false, message: 'City name can only contain letters, spaces, hyphens, and apostrophes' };
        }
        
        if (trimmedCity.length < 2) {
            return { isValid: false, message: 'City name must be at least 2 characters' };
        }
        
        if (trimmedCity.length > 50) {
            return { isValid: false, message: 'City name cannot exceed 50 characters' };
        }
        
        return { isValid: true, message: '' };
    }
    
    /**
     * Validate person name
     * @param {string} name - Name to validate
     * @param {string} fieldName - Name of the field for error message
     * @returns {object} - {isValid: boolean, message: string}
     */
    static validatePersonName(name, fieldName) {
        if (!name || name.trim().length === 0) {
            return { isValid: false, message: `${fieldName} is required` };
        }
        
        const trimmedName = name.trim();
        
        // Names should only contain letters, spaces, hyphens, and apostrophes
        const nameRegex = /^[a-zA-Z\s\-'\.]+$/;
        if (!nameRegex.test(trimmedName)) {
            return { isValid: false, message: `${fieldName} can only contain letters, spaces, hyphens, apostrophes, and periods` };
        }
        
        if (trimmedName.length < 2) {
            return { isValid: false, message: `${fieldName} must be at least 2 characters` };
        }
        
        if (trimmedName.length > 100) {
            return { isValid: false, message: `${fieldName} cannot exceed 100 characters` };
        }
        
        return { isValid: true, message: '' };
    }
    
    /**
     * Validate textarea content
     * @param {string} text - Text content to validate
     * @param {string} fieldName - Name of the field for error message
     * @param {number} maxLength - Maximum length allowed
     * @param {boolean} required - Whether the field is required
     * @returns {object} - {isValid: boolean, message: string}
     */
    static validateTextarea(text, fieldName, maxLength = 255, required = false) {
        if (!text || text.trim().length === 0) {
            if (required) {
                return { isValid: false, message: `${fieldName} is required` };
            }
            return { isValid: true, message: '' };
        }
        
        if (text.length > maxLength) {
            return { isValid: false, message: `${fieldName} cannot exceed ${maxLength} characters` };
        }
        
        return { isValid: true, message: '' };
    }
    
    /**
     * Format phone number for display
     * @param {string} phone - Phone number to format
     * @returns {string} - Formatted phone number
     */
    static formatPhoneNumber(phone) {
        if (!phone) return '';
        
        const cleanPhone = phone.replace(/\D/g, '');
        
        if (cleanPhone.length === 10) {
            return `(${cleanPhone.slice(0, 3)}) ${cleanPhone.slice(3, 6)}-${cleanPhone.slice(6)}`;
        }
        
        return phone;
    }
    
    /**
     * Format ZIP code for display
     * @param {string} zip - ZIP code to format
     * @returns {string} - Formatted ZIP code
     */
    static formatZipCode(zip) {
        if (!zip) return '';
        
        const cleanZip = zip.replace(/\D/g, '');
        
        if (cleanZip.length === 5) {
            return cleanZip;
        } else if (cleanZip.length === 9) {
            return `${cleanZip.slice(0, 5)}-${cleanZip.slice(5)}`;
        }
        
        return zip;
    }
    
    /**
     * Validate all fields in a form data object
     * @param {object} formData - Form data to validate
     * @param {array} fieldConfigs - Array of field configuration objects
     * @returns {object} - {isValid: boolean, errors: object}
     */
    static validateFormData(formData, fieldConfigs) {
        const errors = {};
        let isValid = true;
        
        fieldConfigs.forEach(config => {
            const value = formData[config.fieldName];
            let validation = { isValid: true, message: '' };
            
            switch (config.type) {
                case 'email':
                    validation = this.validateEmail(value);
                    break;
                case 'phone':
                    validation = this.validatePhone(value);
                    break;
                case 'zip':
                    validation = this.validateZip(value);
                    break;
                case 'required':
                    validation = this.validateRequired(value, config.label, config.minLength, config.maxLength);
                    break;
                case 'text':
                    validation = this.validateText(value, config.label, config.allowSpecialChars);
                    break;
                case 'address':
                    validation = this.validateAddress(value, config.label, config.required);
                    break;
                case 'city':
                    validation = this.validateCity(value);
                    break;
                case 'personName':
                    validation = this.validatePersonName(value, config.label);
                    break;
                case 'textarea':
                    validation = this.validateTextarea(value, config.label, config.maxLength, config.required);
                    break;
                case 'vendorNumber':
                    validation = this.validateVendorNumber(value);
                    break;
                default:
                    if (config.required && (!value || value.trim().length === 0)) {
                        validation = { isValid: false, message: `${config.label} is required` };
                    }
            }
            
            if (!validation.isValid) {
                errors[config.fieldName] = validation.message;
                isValid = false;
            }
        });
        
        return { isValid, errors };
    }
}