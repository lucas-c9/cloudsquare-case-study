import { LightningElement, track } from 'lwc';
import submitApplication from '@salesforce/apex/ApplicationController.submitApplication';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class ApplicationForm extends LightningElement {
    
    @track formData = {
        companyName: '',
        email: '',
        phone: '',
        firstName: '',
        lastName: '',
        federalTaxId: '',
        annualRevenue: null
    };
    
    @track isSubmitting = false;
    @track showSuccess = false;
    @track showError = false;
    @track successMessage = '';
    @track errorMessage = '';
    @track resultDetails = null;
    
    handleInputChange(event) {
        const field = event.target.dataset.field;
        let value = event.target.value;
        
        if (field === 'annualRevenue') {
            value = value ? parseFloat(value.replace(/[^0-9.-]+/g, '')) : null;
        }
        
        this.formData[field] = value;
    }
    
    validateForm() {
        const allValid = [
            ...this.template.querySelectorAll('lightning-input'),
        ].reduce((validSoFar, inputCmp) => {
            inputCmp.reportValidity();
            return validSoFar && inputCmp.checkValidity();
        }, true);
        
        return allValid;
    }
    
    async handleSubmit(event) {
        event.preventDefault();
        
        this.showSuccess = false;
        this.showError = false;
        
        if (!this.validateForm()) {
            this.showToast('Error', 'Please fill in all required fields correctly', 'error');
            return;
        }
        
        this.isSubmitting = true;
        
        try {
            const result = await submitApplication({ request: this.formData });
            
            if (result.success) {
                this.handleSuccess(result);
            } else {
                this.handleError(result.errorMessage);
            }
            
        } catch (error) {
            this.handleError(this.reduceErrors(error));
        } finally {
            this.isSubmitting = false;
        }
    }
    
    handleSuccess(result) {
        this.showSuccess = true;
        this.resultDetails = result;
        
        if (result.matchFound) {
            this.successMessage = `Thank you! We found your company in our system and created an opportunity. Our team will contact you soon.`;
        } else {
            this.successMessage = `Thank you for your submission! We've created a new lead and will review your application shortly.`;
        }
        
        this.showToast('Success', this.successMessage, 'success');
        
        setTimeout(() => {
            this.resetForm();
        }, 3000);
    }
    
    handleError(errorMessage) {
        this.showError = true;
        this.errorMessage = errorMessage;
        this.showToast('Error', errorMessage, 'error');
    }
    
    resetForm() {
        this.formData = {
            companyName: '',
            email: '',
            phone: '',
            firstName: '',
            lastName: '',
            federalTaxId: '',
            annualRevenue: null
        };
        
        const inputs = this.template.querySelectorAll('lightning-input');
        if (inputs) {
            inputs.forEach(input => {
                input.value = '';
            });
        }
        
        this.showSuccess = false;
        this.showError = false;
    }
    
    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
            mode: 'dismissable'
        });
        this.dispatchEvent(event);
    }
    
    reduceErrors(error) {
        if (!error) {
            return 'Unknown error';
        }
        
        if (Array.isArray(error.body)) {
            return error.body.map(e => e.message).join(', ');
        } else if (error.body && typeof error.body.message === 'string') {
            return error.body.message;
        } else if (typeof error.message === 'string') {
            return error.message;
        }
        
        return 'An error occurred. Please try again.';
    }
    
    get formattedRevenue() {
        return this.formData.annualRevenue ? 
            new Intl.NumberFormat('en-US', { 
                style: 'currency', 
                currency: 'USD',
                minimumFractionDigits: 0
            }).format(this.formData.annualRevenue) : '';
    }
}