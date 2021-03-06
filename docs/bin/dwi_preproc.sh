#!/bin/bash

#DWI preprocessing

#Push dir to dwi folder
if [ ! -d $DMR ]
then
    mkdir $DMR
fi
pushd $DMR

if [ "$DWI_REVERSED" = "no" ]
then

    #Convert dicoms or nifti to .mif
    mrconvert $DWI ./dwi_raw.mif -force

    #Preprocess with eddy correct (no topup applicable here)
    #ap direction doesn’t matter in this case if NOT reversed
    dwipreproc $DWI_PE_DIR ./dwi_raw.mif ./dwi.mif -rpe_none -nthreads $MRTRIX_THRDS -force

else
    if [ "$DWI_INPUT_FRMT" = "dicom" ]
    then
        #ELSEIF reversed:
        mrchoose 0 mrconvert $DATA/DWI ./dwi_raw.mif -force
        mrchoose 1 mrconvert $DATA/DWI ./dwi_raw_re.mif -force
    else
        mrconvert $DATA/DWI/dwi_raw.nii.gz ./dwi_raw.mif -force
        mrconvert $DATA/DWI/dwi_raw_re.nii.gz ./dwi_raw_re.mif -force
    fi
    dwipreproc $DWI_PE_DIR ./dwi_raw.mif ./dwi.mif -rpe_pair ./dwi_raw.mif ./dwi_raw_re.mif -nthreads $MRTRIX_THRDS -force
fi

#Create brain mask
dwi2mask ./dwi.mif ./mask.mif -nthreads $MRTRIX_THRDS -force
#Extract bzero…
dwiextract ./dwi.mif ./b0.nii.gz -bzero -nthreads $MRTRIX_THRDS -force

#Snapshot
mrconvert ./mask.mif ./mask.nii.gz
python -m $SNAPSHOT --snapshot_name b0_mask --ras_transform 2vols ./b0.nii.gz ./mask.nii.gz

popd


