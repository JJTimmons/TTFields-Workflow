function mysegment(dirname,baseFilename,isSmooth)
% mysegment(dirname,baseFilename,isSmooth)
%
% This function performs automated clean up on the output of SPM8 New Segmentation.
% It does the following:
%
% 1. Smooth the mask if it's not clean enough, to avoid convergence problem
% in the subsequent meshing using ScanIP (default isSmooth==1, with smoothing).
% 2. Create binary mask for each tissue class.
% 3. Fix csf continuity.
% 4. Identify the disconnected voxels, and make them as unassigned voxels
% (empty voxels).
% 5. Relabel each empty voxel to its nearest tissue type.
% 6. Remove the air outside the head.
%
% It accepts 6 tissue types by default.
% dirname specifies the directory where the input NIfTI (.nii) files are stored.
% baseFilename is the base file names of the input .nii files.
% Each tissue class is specified by two characters at the begining of this
% name as 'c1', 'c2', etc.
% The output are the 6 binarized and cleaned tissue masks (mask_gray.nii,
% mask_white.nii, mask_csf.nii, mask_bone.nii, mask_skin.nii, mask_air.nii).
%
% Example:
% mysegment('C:\documents\head 1','MPRAGE'); expects outputs in directory
% C:\documents\head 1 with input files named: c1MPRAGE.nii, c2MPRAGE.nii,
% etc.
% mysegment('C:\documents\head 1','MPRAGE',0); does the same clean up but
% without any tissue smoothing.
%
% (c) Yu Huang (Andy), Lucas C. Parra, August 2011
% (c) Zhewei Jiang, Jacek Dmochowski, July 2010
% The Neural Engineering Lab, Dept. of Biomedical Engineering, City College of New York
% Send bugs to yhuang16@citymail.cuny.edu

if nargin < 3
    isSmooth = 1; % smooth the tissue by default
end

disp('loading data...')
cd(dirname)
gray = load_untouch_nii(['c1' baseFilename '.nii']);
white = load_untouch_nii(['c2' baseFilename '.nii']);
csf = load_untouch_nii(['c3' baseFilename '.nii']);
bone = load_untouch_nii(['c4' baseFilename '.nii']);
skin = load_untouch_nii(['c5' baseFilename '.nii']);
air = load_untouch_nii(['c6' baseFilename '.nii']);
% load the masks

gray_temp = gray.img; white_temp = white.img; csf_temp = csf.img;
bone_temp = bone.img; skin_temp = skin.img; air_temp = air.img;

if isSmooth
    disp('smoothing GM...')
    smt_fil = fspecial('gaussian', 5, 0.2);
    for i = 1:size(gray_temp,3)
        gray_temp(:,:,i) = imfilter(gray_temp(:,:,i),smt_fil);
    end
    
    disp('smoothing WM...')
    smt_fil = fspecial('gaussian', 5, 0.1);
    for i = 1:size(white_temp,3)
        white_temp(:,:,i) = imfilter(white_temp(:,:,i),smt_fil);
    end
    
    disp('smoothing CSF...')
    smt_fil = fspecial('gaussian', 5, 0.1);
    for i = 1:size(csf_temp,3)
        csf_temp(:,:,i) = imfilter(csf_temp(:,:,i),smt_fil);
    end
    
    disp('smoothing bone...')
    smt_fil = fspecial('gaussian', 5, 0.4);
    for i = 1:size(bone_temp,3)
        bone_temp(:,:,i) = imfilter(bone_temp(:,:,i),smt_fil);
    end
    
    disp('smoothing skin...')
    smt_fil = fspecial('gaussian', 5, 1);
    for i = 1:size(skin_temp,3)
        skin_temp(:,:,i) = imfilter(skin_temp(:,:,i),smt_fil);
    end
    
    disp('smoothing air...')
    smt_fil = fspecial('gaussian', 5, 1);
    for i = 1:size(air_temp,3)
        air_temp(:,:,i) = imfilter(air_temp(:,:,i),smt_fil);
    end
end
% Smooth the mask if it's not clean enough, to avoid convergence problem
% in the subsequent meshing using ScanIP

disp('creating binary masks...')
[empt_temp,gray_temp,white_temp,csf_temp,bone_temp,skin_temp,air_temp]...
    = binaryMaskGenerate(gray_temp,white_temp,csf_temp,bone_temp,skin_temp,air_temp);
% Create binary mask for each tissue class

disp('fixing CSF continuity...')
se=ones(3,3,3);
dcsf=imdilate(csf_temp, se);
dbone=imdilate(bone_temp, se);
contin=(empt_temp&dcsf)|(dbone&gray_temp);
csf_temp=csf_temp|contin;

[~,csf_temp,bone_temp,gray_temp]...
    = binaryMaskGenerate(csf_temp,bone_temp,gray_temp); % NOTE: no removal, then no empty voxel generated
% Fix csf continuity

disp('removing disconnected voxels for GM...')
thres = 30;
gray_temp = bwareaopen(gray_temp,thres);

disp('removing disconnected voxels for WM...')
thres = 20;
white_temp = bwareaopen(white_temp,thres);

disp('removing disconnected voxels for CSF...')
siz = sizeOfObject(csf_temp);
thres = siz(4)+1;
csf_temp = bwareaopen(csf_temp,thres);

disp('removing disconnected voxels for bone...')
thres = 300;
bone_temp = bwareaopen(bone_temp,thres);

disp('removing disconnected voxels for skin...')
siz = sizeOfObject(skin_temp);
thres = siz(2)+1;
skin_temp = bwareaopen(skin_temp,thres);

disp('removing disconnected voxels for air...')
thres = 20;
air_temp=bwareaopen(air_temp,thres);
% Identify the disconnected voxels

disp('generating and labeling empty voxels...')
empt_temp = binaryMaskGenerate(gray_temp,white_temp,csf_temp,bone_temp,skin_temp,air_temp);
% Generate unassigned voxels (empty voxels)

for j = 1:2 % usually all empty voxels will be labelled in two loops
    gray_fil = uint8(gray_temp)*255; white_fil = uint8(white_temp)*255;
    csf_fil = uint8(csf_temp)*255; bone_fil = uint8(bone_temp)*255;
    skin_fil = uint8(skin_temp)*255; air_fil = uint8(air_temp)*255;
    sigma = [1 1 1 1 1 1];
    smt_fil = fspecial('gaussian', 5, sigma(1));
    for i = 1:size(gray_fil,3)
        img = gray_fil(:,:,i);
        gray_fil(:,:,i) = imfilter(img,smt_fil);
    end
    smt_fil = fspecial('gaussian', 5, sigma(2));
    for i = 1:size(white_fil,3)
        img = white_fil(:,:,i);
        white_fil(:,:,i) = imfilter(img,smt_fil);
    end
    smt_fil = fspecial('gaussian', 5, sigma(3));
    for i = 1:size(csf_fil,3)
        img = csf_fil(:,:,i);
        csf_fil(:,:,i) = imfilter(img,smt_fil);
    end
    smt_fil = fspecial('gaussian', 5, sigma(4));
    for i = 1:size(bone_fil,3)
        img = bone_fil(:,:,i);
        bone_fil(:,:,i) = imfilter(img,smt_fil);
    end
    smt_fil = fspecial('gaussian', 5, sigma(5));
    for i = 1:size(skin_fil,3)
        img = skin_fil(:,:,i);
        skin_fil(:,:,i) = imfilter(img,smt_fil);
    end
    smt_fil = fspecial('gaussian', 5, sigma(6));
    for i = 1:size(air_fil,3)
        img = air_fil(:,:,i);
        air_fil(:,:,i) = imfilter(img,smt_fil);
    end
    
    [~,air_fil,gray_fil,white_fil,csf_fil,bone_fil,skin_fil]...
        = binaryMaskGenerate(air_fil,gray_fil,white_fil,csf_fil,bone_fil,skin_fil);

    gray_temp = (empt_temp&gray_fil)|gray_temp;
    white_temp = (empt_temp&white_fil)|white_temp;
    csf_temp = (empt_temp&csf_fil)|csf_temp;
    bone_temp = (empt_temp&bone_fil)|bone_temp;
    skin_temp = (empt_temp&skin_fil)|skin_temp;
    air_temp = (empt_temp&air_fil)|air_temp;
    
    empt_temp = xor(empt_temp,((empt_temp&gray_fil) | (empt_temp&white_fil) | (empt_temp&csf_fil)...
        | (empt_temp&bone_fil) | (empt_temp&skin_fil) | (empt_temp&air_fil))); % update empty voxels
end
% Relabel each empty voxel to its nearest tissue type
% The Gaussian filter is used to calculate distances, and max operation
% relabels each empty voxel based on the distances.

disp('removing outside air...')
temp = xor(air_temp, ones(size(air_temp)));
temp = imerode(imfill(imclose(temp,ones(10,10,10)),'holes'),ones(12,12,12));
air_temp = air_temp & temp;
% Remove the air outside the head.

disp('saving results...')
gray.img = uint8(gray_temp)*255; save_untouch_nii(gray,'mask_gray.nii');
white.img = uint8(white_temp)*255; save_untouch_nii(white,'mask_white.nii');
csf.img = uint8(csf_temp)*255; save_untouch_nii(csf,'mask_csf.nii');
bone.img = uint8(bone_temp)*255; save_untouch_nii(bone,'mask_bone.nii');
skin.img = uint8(skin_temp)*255; save_untouch_nii(skin,'mask_skin.nii');
air.img = uint8(air_temp)*255; save_untouch_nii(air,'mask_air.nii');
% save the results with the same header info as the input
disp('DONE! (results were saved as mask_gray.nii, mask_white.nii, mask_csf.nii, mask_bone.nii, mask_skin.nii, mask_air.nii)')
