import { LightningElement, api, track } from 'lwc';

import getFilesFromFolder from '@salesforce/apex/GoogleDriveUpload.getFilesFromFolder';
import moveFileToTrash from '@salesforce/apex/GoogleDriveUpload.moveFileToTrash';
import checkOrCreateSubFolder from '@salesforce/apex/GoogleDriveUpload.checkOrCreateSubFolder';
import generateAndUploadAccountReport from '@salesforce/apex/GoogleDriveUpload.generateAndUploadAccountReport';
import checkExistingReport from '@salesforce/apex/GoogleDriveUpload.checkExistingReport';
import uploadToFolder from '@salesforce/apex/GoogleDriveUpload.uploadToFolder';

import getTrashedFiles from '@salesforce/apex/GoogleDriveUpload.getTrashedFiles';
import restoreFile from '@salesforce/apex/GoogleDriveUpload.restoreFile';
import permanentlyDeleteFile from '@salesforce/apex/GoogleDriveUpload.permanentlyDeleteFile';

import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import LightningConfirm from 'lightning/confirm';
import GOOGLE_DRIVE_ICON from '@salesforce/resourceUrl/GoogleDriveIcon';
import FOLDER_ID_LABEL from '@salesforce/label/c.FolderId';

export default class AccountGoogleDrive extends LightningElement {

    @api recordId;
    parentFolderId = FOLDER_ID_LABEL;
    MAX_FILE_SIZE = 5 * 1024 * 1024; // 5MB in bytes

    // STATE VARIABLES
    subFolderId;
    folderExists = false;
    isInitialized = false;
    isLoading = false;

    isUploadMode = false;
    selectedFile;
    isUploading = false;

    driveIcon = GOOGLE_DRIVE_ICON;

    @track files = [];
    @track trashedFiles = [];

    // LIFECYCLE
    connectedCallback() {
        this.initializeFolder();
    }

    // INITIALIZATION
    async initializeFolder() {
        try {
            this.isLoading = true;
            this.isInitialized = false;

            const result = await checkOrCreateSubFolder({
                parentFolderId: this.parentFolderId,
                accountId: this.recordId,
                createIfMissing: false
            });

            if (result) {
                this.subFolderId = result;
                this.folderExists = true;
                await this.refreshAllFiles();
            } else {
                this.folderExists = false;
            }

        } catch (error) {
            this.showToast('Error', 'Folder check failed ❌', 'error');
        } finally {
            this.isLoading = false;
            this.isInitialized = true;
        }
    }

    async createFolder() {
        try {
            this.isLoading = true;

            const result = await checkOrCreateSubFolder({
                parentFolderId: this.parentFolderId,
                accountId: this.recordId,
                createIfMissing: true
            });

            this.subFolderId = result;
            this.folderExists = true;

            this.showToast('Success', 'Folder created successfully 🎉', 'success');

            await this.loadFiles();

        } catch (error) {
            this.showToast('Error', 'Folder creation failed ❌', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // FILE LOADING
    async loadFiles() {
        if (!this.subFolderId) return;

        try {
            const res = await getFilesFromFolder({
                folderId: this.subFolderId
            });

            const result = JSON.parse(res);

            this.files = result.files.map(file => ({
                ...file,
                formattedSize: this.formatBytes(file.size),
                isPdf: file.mimeType === 'application/pdf'
            }));

        } catch (error) {
            this.showToast('Error', 'Failed to load files ❌', 'error');
        }
    }

    async loadTrashedFiles() {
    try {
        const res = await getTrashedFiles();
        const result = JSON.parse(res);

        // Filter only files deleted from this Account folder
        const filtered = result.files.filter(file =>
            file.parents && file.parents.includes(this.subFolderId)
        );

        this.trashedFiles = filtered.map(file => ({
            ...file,
            formattedSize: this.formatBytes(file.size),
            formattedDate: new Date(file.modifiedTime).toLocaleString()
        }));

    } catch (error) {
        this.showToast('Error', 'Failed to load trashed files ❌', 'error');
    }
}

async refreshAllFiles() {
    await Promise.all([
        this.loadFiles(),
        this.loadTrashedFiles()
    ]);
}

    // UPLOAD SECTION
    handleUploadToggle(event) {
        this.isUploadMode = event.target.checked;
    }

    get selectedFileName() {
        return this.selectedFile ? this.selectedFile.name : null;
    }

    get isUploadDisabled() {
        return this.isUploading || !this.selectedFile;
    }

    handleFileChange(event) {
        const file = event.target.files[0];

        if (!file) {
            this.selectedFile = null;
            return;
        }

        // Validate file size
        if (file.size > this.MAX_FILE_SIZE) {
            this.showToast(
                'File Too Large',
                'File size must be less than 5 MB.',
                'error'
            );

            this.clearSelectedFile();
            return;
        }

        this.selectedFile = file;
    }

    clearSelectedFile() {
        this.selectedFile = null;

        const fileInput = this.template.querySelector(
            'lightning-input[type="file"]'
        );

        if (fileInput) {
            fileInput.value = null;
        }
    }

    async handleUpload() {
        if (!this.selectedFile) {
            this.showToast('Error', 'Please select a file first ❗', 'error');
            return;
        }

        try {
            this.isUploading = true;

            const base64 = await this.convertFileToBase64(this.selectedFile);

            await uploadToFolder({
                fileName: this.selectedFile.name,
                base64Data: base64,
                folderId: this.subFolderId
            });

            this.showToast('Success', 'File uploaded successfully 🎉', 'success');

            this.clearSelectedFile();
            await this.loadFiles();

        } catch (error) {
            this.showToast('Error', 'Upload failed ❌', 'error');
        } finally {
            this.isUploading = false;
        }
    }

    convertFileToBase64(file) {
        return new Promise((resolve, reject) => {

            const reader = new FileReader();

            reader.onload = () => {
                const base64 = reader.result.split(',')[1];
                resolve(base64);
            };

            reader.onerror = error => reject(error);

            reader.readAsDataURL(file);
        });
    }

    // FILE ACTIONS
    handlePreview(event) {
        const fileId = event.currentTarget.dataset.id;
        window.open(
            `https://drive.google.com/file/d/${fileId}/view`,
            '_blank'
        );
    }

    handleDownload(event) {
        const fileId = event.currentTarget.dataset.id;
        window.open(
            `https://drive.google.com/uc?id=${fileId}&export=download`,
            '_blank'
        );
    }

    async handleDeleteClick(event) {

        const fileId = event.currentTarget.dataset.id;

        const confirmDelete = await LightningConfirm.open({
            message: 'Are you sure you want to move this file to trash?',
            theme: 'warning',
            label: 'Confirm Move to Trash'
        });

        if (!confirmDelete) return;

        try {
            await moveFileToTrash({ fileId });

            this.showToast('Success', 'File Moved To Trash 🗑️', 'success');
            await this.refreshAllFiles();

        } catch (error) {
            this.showToast('Error', 'Delete failed ❌', 'error');
        }
    }

    async handleRestore(event) {

    const fileId = event.currentTarget.dataset.id;

    try {
        await restoreFile({ fileId });

        this.showToast('Success', 'File Restored Successfully ♻️', 'success');

        await this.refreshAllFiles();

    } catch (error) {
        this.showToast('Error', 'Restore failed ❌', 'error');
    }
}

async handlePermanentDelete(event) {

    const fileId = event.currentTarget.dataset.id;

    const confirmDelete = await LightningConfirm.open({
        message: 'Are you sure you want to permanently delete this file?',
        theme: 'error',
        label: 'Permanent Delete'
    });

    if (!confirmDelete) return;

    try {
        await permanentlyDeleteFile({ fileId });

        this.showToast('Success', 'File Permanently Deleted 🔥', 'success');

        await this.refreshAllFiles();

    } catch (error) {
        this.showToast('Error', 'Permanent delete failed ❌', 'error');
    }
}

// REPORT GENERATION
    async generateReport() {
        try {
            this.isLoading = true;

            const existingFileId = await checkExistingReport({
                folderId: this.subFolderId,
                accountId: this.recordId
            });

            if (!existingFileId) {
                await generateAndUploadAccountReport({
                    accountId: this.recordId,
                    folderId: this.subFolderId
                });

                this.showToast('Success', 'Account report generated 🎉', 'success');
                await this.loadFiles();
                return;
            }

            // Confirm replacement
            const confirmReplace = await LightningConfirm.open({
                message: 'An existing report already exists. Replace it?',
                theme: 'warning',
                label: 'Replace Report'
            });

            if (!confirmReplace) return;

            // Delete old report
            await moveFileToTrash({ fileId: existingFileId });

            // Generate new report
            await generateAndUploadAccountReport({
                accountId: this.recordId,
                folderId: this.subFolderId
            });

            this.showToast('Success', 'Report replaced successfully 🎉', 'success');
            await this.loadFiles();

        } catch (error) {
            this.showToast('Error', 'Report generation failed ❌', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // UTILITIES
    formatBytes(bytes) {
        if (!bytes) return '—';

        const sizes = ['Bytes', 'KB', 'MB', 'GB'];
        const i = Math.floor(Math.log(bytes) / Math.log(1024));

        return (
            parseFloat((bytes / Math.pow(1024, i)).toFixed(2)) +
            ' ' +
            sizes[i]
        );
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }
}