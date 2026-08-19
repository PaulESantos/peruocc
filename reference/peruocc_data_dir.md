# Configure the directory used for package artifacts

Sets the root directory used for processed data and exported artifacts.
By default, boundaries are cached in a standard user cache directory
(`tools::R_user_dir("peruocc", which = "cache")`) and exported files in
a `peruocc` subdirectory in the current working directory.

## Usage

``` r
peruocc_data_dir(path = NULL)

peruspecies_data_dir(path = NULL)
```

## Arguments

- path:

  Existing or new writable directory.

## Value

The normalized path, invisibly.
