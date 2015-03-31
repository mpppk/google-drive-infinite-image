# Google Drive Infinite Images
Tool for save infinite images in Google Drive.

# Build
**Step 1**  
Get Google Drive App Key and Secret.  
(Look https://developers.google.com/drive/web/enable-sdk)

**Step 2**  
Run the command below.  
(If docker isn't install in your machine, install it first.)

```
docker build -t gdii .
```  

# Usage
**Upload**  
Upload in root collection.
```
docker run -it --rm -v $(pwd):/usr/src/myapp -w /usr/src/myapp gdii upload local_img_dir
```
If you set option "mv", remove local image after uploading.
```
docker run -it --rm -v $(pwd):/usr/src/myapp -w /usr/src/myapp gdii upload local_img_dir mv
```

**Download**
```
docker run -it --rm -v $(pwd):/usr/src/myapp -w /usr/src/myapp gdii download google_drive_img_collection local_img_dir
```

# How we can save infinite images in Google Drive?
In the case of free plan, Google Drive has 15G space.  
However, google document isn't included in the calculation of the remaining space.  
This tool can save infinite images, by upload image as google document and convert to images again when downloading.  
