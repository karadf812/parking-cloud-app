import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getSensors from '@salesforce/apex/ParkingController.getSensors';
import getDefaultPageSize from '@salesforce/apex/ParkingController.getDefaultPageSize';
import processCsvUpload from '@salesforce/apex/ParkingController.processCsvUpload';
import deleteSensor from '@salesforce/apex/ParkingController.deleteSensor';

const COLUMNS = [
    { label: 'Sensor Code', fieldName: 'Name', type: 'text' },
    { label: 'Sensor Model', fieldName: 'Sensor_Model__c', type: 'text' },
    { label: 'Status', fieldName: 'Status__c', type: 'text' },
    { label: 'Base Station', fieldName: 'BaseStationName', type: 'text' },
    { type: 'action', typeAttributes: { rowActions: [{ label: 'Delete', name: 'delete' }] } }
];

export default class ParkingSensorViewer extends LightningElement {
    columns = COLUMNS;
    @track sensors = [];
    statusFilter = 'All';
    pageNumber = 1;
    pageSize = 10;
    totalRecords = 0;
    totalPages = 1;

    statusOptions = [
        { label: 'All', value: 'All' },
        { label: 'Active', value: 'Active' },
        { label: 'Inactive', value: 'Inactive' }
    ];

    connectedCallback() {
        this.loadPageSize();
    }

    loadPageSize() {
        getDefaultPageSize()
            .then(size => {
                this.pageSize = size;
                this.fetchSensors();
            })
            .catch(() => {
                this.showToast('Error', 'Failed to load page size settings', 'error');
            });
    }

    fetchSensors() {
        getSensors({ statusFilter: this.statusFilter, pageNumber: this.pageNumber, pageSize: this.pageSize })
            .then(result => {
                this.sensors = result.sensors.map(sensor => ({
                    ...sensor,
                    BaseStationName: sensor.Base_Station__r ? sensor.Base_Station__r.Name : ''
                }));
                this.totalRecords = result.totalRecords;
                this.totalPages = Math.ceil(this.totalRecords / this.pageSize) || 1;
            })
            .catch(() => {
                this.showToast('Error', 'Error loading sensor records', 'error');
            });
    }

    handleFilterChange(event) {
        this.statusFilter = event.detail.value;
        this.pageNumber = 1;
        this.fetchSensors();
    }

    handlePrevPage() {
        if (this.pageNumber > 1) {
            this.pageNumber--;
            this.fetchSensors();
        }
    }

    handleNextPage() {
        if (this.pageNumber < this.totalPages) {
            this.pageNumber++;
            this.fetchSensors();
        }
    }

    get isFirstPage() {
        return this.pageNumber <= 1;
    }

    get isLastPage() {
        return this.pageNumber >= this.totalPages;
    }

    handleFileChange(event) {
        const file = event.target.files[0];
        if (file) {
            const reader = new FileReader();
            reader.onload = () => {
                const base64 = reader.result.split(',')[1];
                processCsvUpload({ base64Data: base64 })
                    .then(() => {
                        this.showToast('Success', 'CSV file uploaded and processed successfully', 'success');
                        this.fetchSensors();
                    })
                    .catch(error => {
                        this.showToast('Error Uploading CSV', error.body.message, 'error');
                    });
            };
            reader.readAsDataURL(file);
        }
    }

    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;
        if (actionName === 'delete') {
            deleteSensor({ recordId: row.Id })
                .then(() => {
                    this.showToast('Success', 'Sensor deleted successfully', 'success');
                    this.fetchSensors();
                })
                .catch(error => {
                    this.showToast('Error', error.body.message, 'error');
                });
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}