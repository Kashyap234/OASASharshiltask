import { ShowToastEvent } from 'lightning/platformShowToastEvent';

/**
 * Centralized error handling utility for GPS Application
 * Provides consistent error handling and user feedback
 */
export class GPSErrorHandler {
    
    /**
     * Handle and display error to user
     * @param {Error} error - Error object
     * @param {Object} context - Error context information
     * @param {Object} component - LWC component instance for dispatching events
     */
    static handleError(error, context = {}, component = null) {
        const errorInfo = this.parseError(error);
        const userMessage = this.getUserFriendlyMessage(errorInfo, context);
        
        // Log detailed error for debugging
        this.logError(error, context, errorInfo);
        
        // Show user-friendly message
        if (component) {
            this.showToast(component, 'Error', userMessage, 'error');
        }
        
        return {
            userMessage,
            technicalMessage: errorInfo.message,
            code: errorInfo.code
        };
    }

    /**
     * Handle success messages
     * @param {String} message - Success message
     * @param {Object} component - LWC component instance
     * @param {String} title - Toast title
     */
    static handleSuccess(message, component, title = 'Success') {
        if (component) {
            this.showToast(component, title, message, 'success');
        }
    }

    /**
     * Handle warning messages
     * @param {String} message - Warning message
     * @param {Object} component - LWC component instance
     * @param {String} title - Toast title
     */
    static handleWarning(message, component, title = 'Warning') {
        if (component) {
            this.showToast(component, title, message, 'warning');
        }
    }

    /**
     * Parse error object to extract meaningful information
     * @param {Error} error - Error object
     * @returns {Object} Parsed error information
     */
    static parseError(error) {
        let message = 'An unexpected error occurred';
        let code = 'UNKNOWN_ERROR';
        let details = null;

        if (error) {
            // Salesforce Apex errors
            if (error.body) {
                if (error.body.message) {
                    message = error.body.message;
                }
                if (error.body.exceptionType) {
                    code = error.body.exceptionType;
                }
                if (error.body.fieldErrors) {
                    details = error.body.fieldErrors;
                }
                if (error.body.pageErrors) {
                    details = error.body.pageErrors;
                }
            }
            // Standard JavaScript errors
            else if (error.message) {
                message = error.message;
                code = error.name || 'JAVASCRIPT_ERROR';
            }
            // String errors
            else if (typeof error === 'string') {
                message = error;
            }
        }

        return { message, code, details };
    }

    /**
     * Get user-friendly error message
     * @param {Object} errorInfo - Parsed error information
     * @param {Object} context - Error context
     * @returns {String} User-friendly message
     */
    static getUserFriendlyMessage(errorInfo, context) {
        const { code, message } = errorInfo;
        const operation = context.operation || 'operation';

        // Map technical errors to user-friendly messages
        const errorMap = {
            'FIELD_CUSTOM_VALIDATION_EXCEPTION': 'Please check your input and try again.',
            'REQUIRED_FIELD_MISSING': 'Please fill in all required fields.',
            'INVALID_EMAIL_ADDRESS': 'Please enter a valid email address.',
            'DUPLICATE_VALUE': 'This record already exists.',
            'INSUFFICIENT_ACCESS_OR_READONLY': 'You do not have permission to perform this action.',
            'STORAGE_LIMIT_EXCEEDED': 'Storage limit exceeded. Please contact your administrator.',
            'NETWORK_ERROR': 'Network connection error. Please check your connection and try again.',
            'TIMEOUT_ERROR': 'The request timed out. Please try again.',
            'VALIDATION_ERROR': 'Please correct the validation errors and try again.'
        };

        // Return mapped message or fallback to technical message
        return errorMap[code] || `Failed to ${operation}: ${message}`;
    }

    /**
     * Log error for debugging
     * @param {Error} error - Original error
     * @param {Object} context - Error context
     * @param {Object} errorInfo - Parsed error info
     */
    static logError(error, context, errorInfo) {
        const logData = {
            timestamp: new Date().toISOString(),
            context: context,
            errorInfo: errorInfo,
            stackTrace: error?.stack,
            userAgent: navigator.userAgent
        };

        console.group('🚨 GPS Application Error');
        console.error('Error Details:', logData);
        console.error('Original Error:', error);
        console.groupEnd();

        // In production, you might want to send this to a logging service
        // this.sendToLoggingService(logData);
    }

    /**
     * Show toast message
     * @param {Object} component - LWC component instance
     * @param {String} title - Toast title
     * @param {String} message - Toast message
     * @param {String} variant - Toast variant (success, error, warning, info)
     */
    static showToast(component, title, message, variant = 'info') {
        const event = new ShowToastEvent({
            title,
            message,
            variant,
            mode: 'dismissible'
        });
        component.dispatchEvent(event);
    }

    /**
     * Create error boundary for async operations
     * @param {Function} asyncFunction - Async function to wrap
     * @param {Object} context - Error context
     * @param {Object} component - LWC component instance
     * @returns {Function} Wrapped function
     */
    static createErrorBoundary(asyncFunction, context, component) {
        return async (...args) => {
            try {
                return await asyncFunction(...args);
            } catch (error) {
                this.handleError(error, context, component);
                throw error; // Re-throw for caller to handle if needed
            }
        };
    }

    /**
     * Validate and handle field errors
     * @param {Object} fieldErrors - Field validation errors
     * @param {Object} component - LWC component instance
     */
    static handleFieldErrors(fieldErrors, component) {
        if (!fieldErrors || Object.keys(fieldErrors).length === 0) {
            return;
        }

        const errorMessages = [];
        Object.keys(fieldErrors).forEach(fieldName => {
            const fieldError = fieldErrors[fieldName];
            if (Array.isArray(fieldError)) {
                fieldError.forEach(error => {
                    errorMessages.push(`${fieldName}: ${error.message}`);
                });
            } else {
                errorMessages.push(`${fieldName}: ${fieldError.message || fieldError}`);
            }
        });

        const message = errorMessages.join('\n');
        this.showToast(component, 'Validation Errors', message, 'error');
    }

    /**
     * Handle network errors specifically
     * @param {Error} error - Network error
     * @param {Object} component - LWC component instance
     */
    static handleNetworkError(error, component) {
        const context = { operation: 'network request', type: 'NETWORK_ERROR' };
        this.handleError(error, context, component);
    }

    /**
     * Handle validation errors specifically
     * @param {Array|String} validationErrors - Validation errors
     * @param {Object} component - LWC component instance
     */
    static handleValidationErrors(validationErrors, component) {
        const errors = Array.isArray(validationErrors) ? validationErrors : [validationErrors];
        const message = errors.join('. ');
        this.showToast(component, 'Validation Error', message, 'error');
    }
}