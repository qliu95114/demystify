# This script extracts portraits from a photo.
# The input parameter is the path to an image file, denoted as 'image_path'.
# The script checks if the photo contains one or more persons.
# The output displays how many faces have been detected in the image file.
# The output photos are saved in the $env:temp folder, named following the format 'inputfilename_face_x.jpg'.

# Usage: This script relies on the Open CV2 library.
# To install cv2, run the command: pip install opencv-python
# To execute the script, use the command: 
#      python extract_portrait.py C:\\Users\\user\\Desktop\\test.jpg

# Expected output 
# PS D:\> python.exe .\extract_portrait.py D:\Camera\2023-10-25_5K_1.png
# [[ 540  804  122  122]
#  [1266  577  160  160]
#  [2468  590  138  138]
#  [ 676  909   59   59]
#  [2198  561  132  132]]
# # Number of faces detected:  5
# C:\Users\user\AppData\Local\Temp\2023-10-25_5K_1_face_1.jpg
# C:\Users\user\AppData\Local\Temp\2023-10-25_5K_1_face_2.jpg
# C:\Users\user\AppData\Local\Temp\2023-10-25_5K_1_face_3.jpg
# C:\Users\user\AppData\Local\Temp\2023-10-25_5K_1_face_4.jpg
# C:\Users\user\AppData\Local\Temp\2023-10-25_5K_1_face_5.jpg

import cv2
import os
import sys

def detect_faces(image_path):
# Load the cascade
    face_cascade = cv2.CascadeClassifier(cv2.data.haarcascades + 'haarcascade_frontalface_default.xml')

    # To read the image
    img = cv2.imread(image_path)

    if img is None:
        print("The image '"+image_path+"'is not valid. Please check again.")
        sys.exit()

    # To convert to grayscale
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)

    # Detect the faces, 
    faces = face_cascade.detectMultiScale(gray, 1.3, 10)

    # To print the coordinates of the face detected
    print(faces)
    # To print the number of faces detected
    print("Number of faces detected: ", len(faces))

    # Draw the rectangle around each face
    face_count = 0
    for (x, y, w, h) in faces:  # x,y is the left top corner of the face, w is the width of the face, h is the height of the face
        face_count += 1
        # make the section more large when extract the face
        roi_color = img[y-100:y + h+100, x-100:x + w+100]
        #cv2.imwrite(os.path.join(os.getenv('TEMP'), os.path.basename(image_path).split('.')[0] + '_face_' + str(face_count) + '.jpg'), roi_color)
        # make the section image to a standard size 1024x1024
        roi_color_standard = cv2.resize(roi_color, (800, 800))
        cv2.imwrite(os.path.join(os.getenv('TEMP'), os.path.basename(image_path).split('.')[0] + '_face_' + str(face_count) + '.jpg'), roi_color_standard)
        print(os.path.join(os.getenv('TEMP'), os.path.basename(image_path).split('.')[0] + '_face_' + str(face_count) + '.jpg'))
    

# if sys.argv[1] is None: print out sample usage
# if sys.argv[1] is not None and file exist call detect_faces

if len(sys.argv) > 1:
    if os.path.isfile(sys.argv[1]):
        detect_faces(sys.argv[1])
    else:
        print("'"+ sys.argv[1] + "' does not exist. Please check again.")    
else:  
    #print("  [ERROR] You must have one arg to the path of image")
    print("[Example] python extract_portrait.py C:\\Users\\user\\Desktop\\test.jpg")
    sys.exit()

