# -*- coding: utf-8 -*-

import os
import subprocess

import sys

from tvb.recon.algo.service.surface import SurfaceService
from tvb.recon.io.factory import IOUtils
from tvb.recon.model.mapping import Mapping


def create_tvb_dataset(cort_surf_direc: os.PathLike,
                       label_direc: os.PathLike,
                       mri_direc: os.PathLike,
                       out_surfaces_dir: os.PathLike = None):
    annotation_io = IOUtils.annotation_io_factory("lh.aparc.annot")
    annot_cort_lh = annotation_io.read(os.path.join(label_direc, "lh.aparc.annot"))
    annot_cort_rh = annotation_io.read(os.path.join(label_direc, "rh.aparc.annot"))

    annot_subcort_lh = annotation_io.read(os.path.join(label_direc, "lh.aseg.annot"))
    annot_subcort_rh = annotation_io.read(os.path.join(label_direc, "rh.aseg.annot"))

    mapping = Mapping(annot_cort_lh, annot_cort_rh, annot_subcort_lh, annot_subcort_rh)
    mapping.generate_region_mapping_for_cort_annot(annot_cort_lh, annot_cort_rh)
    mapping.generate_region_mapping_for_subcort_annot(annot_subcort_lh, annot_subcort_rh)

    surface_service = SurfaceService()

    surface_io = IOUtils.surface_io_factory("lh.pial")
    surf_cort_lh = surface_io.read(os.path.join(cort_surf_direc, "lh.pial"), False)
    surf_cort_rh = surface_io.read(os.path.join(cort_surf_direc, "rh.pial"), False)

    full_cort_surface = surface_service.merge_surfaces([surf_cort_lh, surf_cort_rh])

    surf_subcort_lh = surface_io.read(os.path.join(cort_surf_direc, "lh.aseg"), False)
    surf_subcort_rh = surface_io.read(os.path.join(cort_surf_direc, "rh.aseg"), False)

    full_subcort_surface = surface_service.merge_surfaces([surf_subcort_lh, surf_subcort_rh])

    if out_surfaces_dir:
        with open(os.path.join(out_surfaces_dir, "region_mapping_cort.txt"), "w") as f:
            for rm_val in mapping.cort_region_mapping:
                f.write("%s\n" % rm_val)
        with open(os.path.join(out_surfaces_dir, "region_mapping_subcort.txt"), "w") as f:
            for rm_val in mapping.subcort_region_mapping:
                f.write("%s\n" % rm_val)

        subprocess.call(
            ["mri_info", "--vox2ras", os.path.join(mri_direc, "T1.mgz"), "--o", os.path.join(out_surf, "vox2ras.txt")])

        io_utils = IOUtils()
        surf_subcort_filename = "surface_subcort.zip"
        surface_io = io_utils.surface_io_factory(surf_subcort_filename)
        surface_io.write(full_subcort_surface, os.path.join(out_surfaces_dir, surf_subcort_filename))

        surf_cort_filename = "surface_cort.zip"
        surface_io = io_utils.surface_io_factory(surf_cort_filename)
        surface_io.write(full_cort_surface, os.path.join(out_surfaces_dir, surf_cort_filename))

    # This is useful for aseg_aparc mapping
    # annotation_service = AnnotationService()
    # lut_dict, _, _ = annotation_service.read_lut("/WORK/FS/freesurfer/FreeSurferColorLUT.txt", "name")
    # rm_index_dict = mapping.get_index_mapping_for_lut(lut_dict)
    #
    # with open(os.path.join(out_surf, "mapping_fs_custom.txt"), "w") as f:
    #     for key, val in rm_index_dict.items():
    #         f.write("%s %s\n" % (key, val))


if __name__ == "__main__":
    subject_dir, out_surf = sys.argv[1:]

    create_tvb_dataset(
        os.path.join(subject_dir, "surf"),
        os.path.join(subject_dir, "label"),
        os.path.join(subject_dir, "mri"),
        out_surf
    )
