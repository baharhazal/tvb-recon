# -*- coding: utf-8 -*-

import pytest
from bnm.recon.io.factory import IOFactory
from bnm.tests.base import get_data_file, get_temporary_files_path, remove_temporary_test_files

TEST_SUBJECT = 'freesurfer_fsaverage'
TEST_ANNOT_FOLDER = 'label'
io_factory = IOFactory()


def teardown_module():
    remove_temporary_test_files()


def test_parse_annotation():
    file_path = get_data_file(TEST_SUBJECT, TEST_ANNOT_FOLDER, "lh.aparc.annot")
    annot = io_factory.read_annotation(file_path)
    assert annot.region_names == ['unknown', 'bankssts', 'caudalanteriorcingulate', 'caudalmiddlefrontal',
                                  'corpuscallosum', 'cuneus', 'entorhinal', 'fusiform', 'inferiorparietal',
                                  'inferiortemporal', 'isthmuscingulate', 'lateraloccipital', 'lateralorbitofrontal',
                                  'lingual', 'medialorbitofrontal', 'middletemporal', 'parahippocampal', 'paracentral',
                                  'parsopercularis', 'parsorbitalis', 'parstriangularis', 'pericalcarine',
                                  'postcentral', 'posteriorcingulate', 'precentral', 'precuneus',
                                  'rostralanteriorcingulate', 'rostralmiddlefrontal', 'superiorfrontal',
                                  'superiorparietal', 'superiortemporal', 'supramarginal', 'frontalpole',
                                  'temporalpole', 'transversetemporal', 'insula']


def test_parse_not_existent_annotation():
    file_path = "not_existent_annotation.annot"
    annotation_io = io_factory.get_annotation_io(file_path)
    with pytest.raises(IOError):
        annotation_io.read(file_path)


def test_parse_not_annotation():
    file_path = get_data_file(TEST_SUBJECT, "surf", "lh.pial")
    annotation_io = io_factory.get_annotation_io(file_path)
    with pytest.raises(ValueError):
        annotation_io.read(file_path)


def test_parse_h5_annotation():
    h5_path = get_data_file('head2', 'RegionMapping.h5')
    annotation = io_factory.read_annotation(h5_path)
    assert len(annotation.region_mapping) == 16


def test_write_annotation():
    file_path = get_data_file(TEST_SUBJECT, TEST_ANNOT_FOLDER, "lh.aparc.annot")
    annotation = io_factory.read_annotation(file_path)

    out_annotation_path = get_temporary_files_path("lh-test.aparc.annot")
    io_factory.write_annotation(out_annotation_path, annotation)

    new_annotation = io_factory.read_annotation(out_annotation_path)
    assert annotation.region_names == new_annotation.region_names