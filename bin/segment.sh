#!/bin/bash

#FLIRT co-registration of gmwmi with aseg

vol=aparc+aseg

pushd $SEGMENT

#Volume workflow:

#Get the voxels that lie at the external surface (or border) of the target volume structures:

#Using my python code:
#python -c "import reconutils; reconutils.vol_to_ext_surf_vol('$MRI/$vol.nii.gz',labels='$ASEG_LIST',hemi='lh rh',out_vol_path='./$vol-surf.nii.gz',labels_surf=None,labels_inner='0')"
#flirt -applyxfm -in ./$vol-surf.nii -ref $DMR/b0.nii.gz -out ./$vol-surf-in-d.nii.gz -init $DMR/t2d.mat -interp nearestneighbour

#Using freesurfer:
mris_calc $MRI/T1.mgz mul 0
for srf in white aseg
do
    for h in lh rh
    do
        mri_surf2vol --mkmask --hemi $h --surf $srf --identity $SUBJECT --template $MRI/T1.mgz --o ./$h.$srf-surf-mask.mgz --vtxvol ./$h.$srf-surf-map.mgz

        mris_calc ./out.mgz or ./$h.$srf-surf-mask.mgz

    done
done
mv ./out.mgz ./$vol-surf-mask.mgz
mris_calc $MRI/$vol.mgz masked ./$vol-surf-mask.mgz
mv ./out.mgz ./$vol-surf.mgz

for v in ./$vol-surf-mask ./$vol-surf
    do
        mri_convert ./$v.mgz ./$v.nii.gz --out_orientation RAS -rt nearest
        fslreorient2std ./$v.nii.gz ./$v-reo.nii.gz
        mv ./$v-reo.nii.gz ./$v.nii.gz
done


if [ "$SEGMENT_METHOD" = "tdi" ] || [ "$SEGMENT_METHOD" = "tdi+gwi" ] || [ "$SEGMENT_METHOD" = "tdi*gwi" ];
then
    pushd $TDI

    if [ -e $DMR/tdi_ends-v1.nii.gz ]
    then
        tdiends=$DMR/tdi_ends-v1.nii.gz
    else
        #Get volume labels:
        tckmap $DMR/$STRMLNS_SIFT_NO.tck ./tdi_ends.mif -vox 1 -ends_only #vox: size of bin
        mrconvert ./tdi_ends.mif ./tdi_ends.nii.gz
        rm ./tdi_ends.mif
        tdiends=./tdi_ends.nii.gz
    fi

    #Get the transform of tdi_ends in T1 space
    #QUESTION! Can we afford the loss of accuracy due to volume resampling from diffusion space and resolution to those of T1?
    #Do we need regopt when we just apply an existing transform?
    regopt="-dof 12 -searchrx -180 180 -searchry -180 180 -searchrz -180 180 -cost mutualinfo -interp nearestneighbour"
    flirt -applyxfm -in $tdiends -ref $MRI/T1.nii.gz -init $DMR/t2d.mat -out ./tdi_ends-in-t1.nii.gz $regopt

    #...and binarize it to create a tdi mask with a threshold equal to a number of tracks
    mri_binarize --i ./tdi_ends-in-t1.nii.gz --min $TDI_THR --o ./tdi_mask.nii.gz

    popd
fi

if [ "$SEGMENT_METHOD" = "gwi" ] || [ "$SEGMENT_METHOD" = "tdi+gwi" ] || [ "$SEGMENT_METHOD" = "tdi*gwi" ];
then
    pushd $GWI

    #Create a mask of vol's white matter
    mri_binarize --i $MRI/$vol.nii.gz --all-wm --o ./wm.nii.gz
    #is this really needed?:
    mri_convert ./wm.nii.gz ./wm.nii.gz --out_orientation RAS -rt nearest
    fslreorient2std ./wm.nii.gz ./wm-reo.nii
    mv ./wm-reo.nii.gz ./wm.nii.gz

    #gmwmi:
    #Anatomically constraint spherical deconvolution
    #5ttgen fsl $MRI/T1.nii.gz ./5tt-in-t1.mif -force #if a brain mask is already applied: -premasked
    5tt2gmwmi ./5tt-in-t1.mif ./gmwmi-in-t1.mif -nthreads $MRTRIX_THRDS -force
    mrconvert ./gmwmi-in-t1.mif ./gmwmi-in-t1.nii.gz -force

    #Scale gmwmi-in-T1 in 0-256 for visualization reasons
    mris_calc ./gmwmi-in-t1.nii.gz mul 256
    mri_convert ./out.mgz ./gmwmi-in-t1-256.nii.gz --out_orientation RAS -rt nearest
    rm ./out.mgz

    #Visual checks
    #(interactive):
    #freeview -v $MRI/T1.nii ../$vol.nii.gz ./gmwmi-in-t1-256.nii:opacity=0.5
    #(screenshot):
    #freeview -v $MRI/T1.nii.gz ../$vol.nii.gz ./gmwmi-in-t1-256.nii.gz:opacity=0.5 -ss $FIGS/gmwmi-in-t1-$vol.png
    #source snapshot.sh 3vols $MRI/T1.nii.gz ../$vol.nii.gz ./gmwmi-in-t1-256.nii.gz

    #Resample and register gmwmi with aparc+aseg
    tkregister2 --mov ./gmwmi-in-t1.nii.gz --targ $MRI/T1.nii.gz --reg ./resamp_gw-in-t1.dat --noedit --regheader
    #Resample gmwmi in aseg space [256 256 256]
    mri_vol2vol --mov ./gmwmi-in-t1.nii.gz --targ $MRI/T1.nii.gz --o ./gmwmi-in-t1-resamp.nii.gz --reg ./resamp_gw-in-t1.dat
    #Renormalize gmwmi in the [0.0, 1.0] interval
    mris_calc ./gmwmi-in-t1-resamp.nii.gz norm
    mri_convert ./out.mgz ./gmwmi-in-t1-resamp-norm.nii.gz --out_orientation RAS -rt nearest
    #rm ./out.mgz
    #...and binarize it to create a gmwmi mask
    mri_binarize --i ./gmwmi-in-t1-resamp-norm.nii.gz --min $GWI_THR --o ./gmwmi-in-t1-bin.mgz
    mri_convert ./gmwmi-in-t1-bin.mgz ./gmwmi-in-t1-bin.nii.gz --out_orientation RAS -rt nearest
    fslreorient2std ./gmwmi-in-t1-bin.nii.gz ./gmwmi-in-t1-bin-reo.nii.gz
    mv ./gmwmi-in-t1-bin-reo.nii.gz ./gmwmi-in-t1-bin.nii.gz

    #Visual checks
    #(interactive):
    #freeview -v $MRI/T1.nii.gz ../$vol.nii.gz ./gmwmi-in-t1-bin.nii.gz:opacity=0.5
    #(screenshot):
    #freeview -v $MRI/T1.nii.gz ../$vol.nii.gz ./gmwmi-in-t1-bin.nii.gz:opacity=0.5 -ss $FIGS/gmwmi-bin-in-$vol.png
    #source snapshot.sh 3vols $MRI/T1.nii.gz ../$vol.nii.gz ./gmwmi-in-t1-bin.nii.gz

    #Create a mask by combining gmwmi-bin and wm masks with logical OR
    mris_calc ./gmwmi-in-t1-bin.nii.gz or ./wm.nii.gz
    mri_convert ./out.mgz ./gwi_mask.nii.gz --out_orientation RAS -rt nearest
    rm ./out.mgz
    fslreorient2std ./gwi_mask.nii.gz ./gwi_mask-reo.nii.gz
    mv ./gwi_mask-reo.nii.gz ./gwi_mask.nii.gz

    popd
fi

if [ "$SEGMENT_METHOD" = "tdi" ]
then
    cp $TDI/tdi_mask.nii.gz ./mask-$SEGMENT_METHOD.nii.gz
elif [ "$SEGMENT_METHOD" = "tdi" ]
then
    cp $GWI/gwi_mask.nii.gz ./mask-$SEGMENT_METHOD.nii.gz
elif [ "$SEGMENT_METHOD" = "tdi+gwi" ] || [ "$SEGMENT_METHOD" = "tdi*gwi" ]
then
    if [ "$SEGMENT_METHOD" = "tdi+gwi" ]
    then
        mris_calc $TDI/tdi_mask.nii.gz or $GWI/gwi_mask.nii.gz
    else
        mris_calc $TDI/tdi_mask.nii.gz and $GWI/gwi_mask.nii.gz
    fi
    mri_convert ./out.mgz ./mask-$SEGMENT_METHOD.nii.gz --out_orientation RAS -rt nearest
    rm ./out.mgz
    fslreorient2std ./mask-$SEGMENT_METHOD.nii.gz ./mask-$SEGMENT_METHOD-reo.nii.gz
    mv ./mask-$SEGMENT_METHOD-reo.nii.gz ./mask-$SEGMENT_METHOD.nii.gz
fi

#Apply the mask to the border voxels

#Using my python code:
#python -c "import reconutils; reconutils.mask_to_vol('./$vol-surf.nii.gz','./mask-$SEGMENT_METHOD.nii.gz','./$vol-mask.nii.gz',labels='$ASEG_LIST',hemi='lh rh',vol2mask_path=None,vn=$VOL_VN,th=1,labels_mask=None,labels_nomask='0')"

#Using freesurfer:
mris_calc ./$vol-surf.nii.gz masked ./mask-$SEGMENT_METHOD.nii.gz
mri_convert ./out.mgz ./$vol-mask.nii.gz --out_orientation RAS -rt nearest
rm ./out.mgz
fslreorient2std ./$vol-mask.nii.gz ./$vol-mask-reo.nii
mv ./$vol-mask-reo.nii.gz ./$vol-mask.nii.gz


#Get final masked surfaces:
for h in lh rh
do
    python -c "import reconutils; reconutils.sample_vol_on_surf('$SURF/$h.aseg','./$vol-mask.nii.gz','$LABEL/$h.aseg.annot','./$h.aseg-mask',surf_ref_path='$SURF/$h.aseg-ras',out_surf_ref_path='./$h.aseg-mask-ras',ctx=None,vn=$SURF_VN)"
done

#Sample the surface with the surviving voxels
for h in lh rh
do
    python -c "import reconutils; reconutils.sample_vol_on_surf('$SURF/$h.white','./$vol-mask.nii.gz','$LABEL/$h.aparc.annot','./$h.white-mask',surf_ref_path='$SURF/$h.white-ras',out_surf_ref_path='./$h.white-mask-ras',ctx='$h',vn=$SURF_VN)"
done


#Take the tdi_lbl to T1 standard space, without upsampling:
#PROBLEM!: when ref is T1, the volume is not resampled correctly, when ref is itself, it produces null result...
regopt="-dof 12 -searchrx -180 180 -searchry -180 180 -searchrz -180 180 -cost mutualinfo -interp nearestneighbour"
flirt $regopt -in $DMR/tdi_lbl-v$VOX.nii.gz -ref $MRI/T1.nii.gz -omat ./tdi_lbl-v$VOX-2-t1.mat -out ./tdi_lbl-v$VOX-in-t1-sizet1.nii.gz
flirt -applyxfm $regopt -in $DMR/tdi_lbl-v$VOX.nii.gz -ref $DMR/tdi_lbl-v$VOX.nii.gz -init $DMR/d2t.mat -out ./tdi_lbl-v$VOX-in-t1.nii.gz


#Compute the voxel connectivity similarity
#This takes a lot of time...
python -c "import reconutils; reconutils.node_connectivity_metric('$DMR/vol-counts$STRMLNS_SIFT_NO-v$VOX.npy',metric='cosine', mode='sim',out_consim_path='./consim-vol-counts$STRMLNS_SIFT_NO-v$VOX.npy')"

popd



