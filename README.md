# 🚀 Salesforce – Google Drive Integration  
### Lightning Web Components (LWC) + Apex + Google Drive REST API

This project integrates **Salesforce** with **Google Drive** to allow users to manage files directly from the **Account record page** using Lightning Web Components and Apex callouts.

It eliminates manual switching between systems by bringing Google Drive functionality inside Salesforce.

---

## 📌 Overview

This solution enables:

- 📂 Creation of Account-specific subfolders in Google Drive
- 📤 File upload directly from Salesforce
- 👀 File preview
- ⬇️ File download
- 🗑️ Move files to Trash
- ♻️ Restore files from Trash
- ❌ Permanent file deletion from Trash
- 📄 Dynamic Account PDF report generation and upload
- 🔐 Folder-level permission management
- 📏 File size validation (Maximum 5MB)
- 🎯 Clean, responsive LWC user interface

---

## 🏗️ Architecture
```text
Salesforce LWC (UI)
↓
Apex Controller (Callouts)
↓
Google Drive REST API
↓
Google Cloud Console (OAuth 2.0)
```
---

## 🌐 Google API Configuration

- **Base URL:** https://www.googleapis.com


- **OAuth Scope:** openid email profile https://www.googleapis.com/auth/drive

---

## 🔧 Google Cloud Console Setup

1. Google Cloud Console > New Project  
2. APIs & Services > Library > Enable **Google Drive API**  
3. APIs & Services > OAuth Consent Screen > Configure Application  
4. APIs & Services > Credentials > Create **OAuth Client ID**
5. Save:
   - Client ID  
   - Client Secret  

---

## ⚙️ Salesforce Auth. Providers Setup

1. Go to Salesforce Setup  
2. Navigate to **Auth. Providers**  
3. Click **New**

Configure:

- **Provider Type:** Google
- **Consumer Key:** Enter Your Client ID 
- **Consumer Secret:** Enter Your Client Secret 
- **Default Scopes:** `openid gmail profile https://www.googleapis.com/auth/drive`

4. **Copy:** Callback URL and add in Authorised redirect URIs(Google Console)

---

## ⚙️ Salesforce Named Credential Setup

1. Go to Salesforce Setup  
2. Navigate to **Named Credentials**  
3. Click **New Legacy**

Configure:

- **URL:** `https://www.googleapis.com`
- **Identity Type:** Named Principal
- **Authentication Protocol:** OAuth 2.0
- **Authentication Provider:** Choose Recent Create Auth. Provider
- **Scope:** `openid gmail profile https://www.googleapis.com/auth/drive`

---

## 📂 Project Structure
```text
force-app
└── main
    └── default
        ├── classes
        │   ├── GoogleDriveUpload.cls
        │   └── AccountPdfGenerator.cls
        └── lwc
            └── accountGoogleDrive
                ├── accountGoogleDrive.html
                ├── accountGoogleDrive.js
                └── accountGoogleDrive.css
```

---

## 📦 Apex Classes

### GoogleDriveUpload.cls
Handles:
- Folder existence check
- Folder creation
- File upload (multipart request)
- File retrieval
- Move files to Trash
- Restore files from Trash
- Permanent file deletion from Trash
- Permission management
- Report upload

### AccountPdfGenerator.cls
- Generates dynamic Account PDF
- Returns Blob for Drive upload

---

## 🔄 Functional Flow

1. User opens an Account record.
2. LWC calls Apex to check if the Account folder exists in Google Drive.
3. If not found, Apex creates a subfolder.
4. Folder-level permission is applied.
5. Users can upload, preview, download, move to trash, restore and permanent delete files.
6. Account PDF report can be generated and uploaded.
7. File size validation ensures files are under 5MB.

---

## 🔐 Security

- OAuth 2.0 authentication
- Named Credentials for secure API callouts
- Folder-level permission management
- No hardcoded credentials
- Controlled API access

---

## 📏 File Validation

- Maximum file size: 5MB
- Client-side validation before upload
- Prevents large API payload failures

---

## 🛠️ Technologies Used

- Salesforce Lightning Web Components (LWC)
- Apex
- Google Drive REST API
- Named Credentials
- OAuth 2.0
- PDF Generation in Apex

---

## 🚀 Deployment Steps

1. Deploy Apex classes.
2. Deploy LWC component.
3. Add `accountGoogleDrive` component to Account Record Page using Lightning App Builder.
4. Configure Named Credential.
5. Authenticate successfully.

---

## 📌 Future Enhancements

- Multiple file upload
- Upload progress indicator
- Domain-restricted access
- Expiring public links
- Drag & Drop upload support
- File type validation

---

## 👨‍💻 Author

Soumya Ranjan Khuntia  
Salesforce Developer  

---

⭐ If you found this useful, consider starring the repository.
