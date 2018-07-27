#! ~/miniconda3/envs/event_creation/bin/python

import numpy as np
from numpy.testing import assert_almost_equal
import nibabel as nib
import pandas as pd
import argparse
import os.path as osp


def map_coords(coordinates, nifti_file):
    """
    Apply the RAS+ transform in a nifti file to a set of coordinates in voxel space
    :param coordinates: Array-like with shape (3,N) or (4,N)
    :param nifti_file: A path to a NIFTII file (.nii or .nii.gz)
    :return ras_coords: The coordinates in the RAS space used by `nifti_file`
    :return vox_vol:
    """
    transform = nib.load(nifti_file).get_affine()

    # Gotta be constistent with the previous impelemntation, despite it
    # being stupid AF
    transform[:3, -1] -= np.diag(transform)[:3]

    if coordinates.shape[0] == 3:
        coordinates = np.concatenate([coordinates,
                                      np.ones((1,coordinates.shape[1]))],)
    coordinates = np.matrix(coordinates)

    assert coordinates.shape[0] == 4

    voxvol = np.abs(np.prod(np.diag(transform)))

    ras_coords = transform.astype(np.matrix) * coordinates

    return ras_coords[:3, :], voxvol


def write_electrode_coordinates(vox_coords_file, nifti_file, electrode_coords_file):
    coords = np.loadtxt(vox_coords_file).T
    pcoords, voxvol = map_coords(coords, nifti_file)

    df = pd.DataFrame(columns= ['x', 'y', 'z'], data=pcoords.T)
    df[['x', 'y']] *= -1
    df['t'] = 0
    df['label'] = np.arange(1, len(df)+1)
    df['mass'] = np.arange(1, len(df)+1)
    df['voxvol'] = voxvol
    df['count'] = 1

    df.to_csv(electrode_coords_file, header=True, mode='w', index=False)


def make_parser():
    parser = argparse.ArgumentParser()
    parser.add_argument('vox_coords_file')
    parser.add_argument('nifti_file')
    parser.add_argument('electrode_coords_file')
    parser.add_argument('--check-values', default=None)
    return parser

if __name__ == "__main__":
    args = make_parser().parse_args()
    write_electrode_coordinates(args.vox_coords_file,args.nifti_file,
                                args.electrode_coords_file)

    if args.check_values is not None:
        new_coords = pd.read_csv(args.electrode_coords_file).values
        new_coords[:, :2] *= -1
        old_coords = pd.read_csv(
            osp.join(osp.dirname(args.electrode_coords_file),
                     args.check_values)
        ).values
        if new_coords.shape != old_coords.shape:
            old_coords = pd.read_csv(
                osp.join(osp.dirname(args.electrode_coords_file),
                         args.check_values),
                header=None).values

        assert_almost_equal(new_coords, old_coords, 3)
