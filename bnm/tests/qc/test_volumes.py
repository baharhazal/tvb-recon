# -*- coding: utf-8 -*-

import pytest
from bnm.recon.qc.parser.volume import VolumeIO
from bnm.tests.base import get_data_file
from nibabel.filebasedimages import ImageFileError
from nibabel.py3k import FileNotFoundError

TEST_MODIF_SUBJECT = 'fsaverage_modified'
TEST_FS_SUBJECT = "freesurfer_fsaverage"
TEST_VOLUME_FOLDER = 'mri'


def test_parse_volume():
    parser = VolumeIO()
    file_path = get_data_file(TEST_MODIF_SUBJECT, TEST_VOLUME_FOLDER, "T1.nii.gz")
    volume = parser.read(file_path)
    assert volume.dimensions == (256, 256, 256)


def test_parse_not_existing_volume():
    parser = VolumeIO()
    file_path = "not-existent-volume.nii.gz"
    with pytest.raises(FileNotFoundError):
        parser.read(file_path)


def test_parse_not_volume():
    parser = VolumeIO()
    file_path = get_data_file(TEST_FS_SUBJECT, "surf", "lh.pial")
    with pytest.raises(ImageFileError):
        parser.read(file_path)
