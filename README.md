# cBioPortal data importer POC

It loads data to the staging zone in the database with minimal transformations to do the rest of operations there (kinda ELT)

## TODO
- test on more data types. e.g. protein level sample_id column look blank in the database
  - how we can control for such silent errors
    - I can use --input_format_allow_missing_columns=0
      but then I have to clean extra table columns (e.g. about). It's a good idea anyway
- simplify the db schema. remove staging from the table names. having staging db is sufficient. some of the columsn (e.g. others) are not used. Maybe we should drop them?
- try to load to the cloud via network. How much slower importer becomes? If much, we can try to load data via clickhouse-local first and then send native binary to the remote server.
- employ 4 parrallel processes (e.g. GNU Parallel) to upload data to the database
- document how to run the importer for external users
- make example of running validations in the db
- implement sql for publishing data from staging zone to prod zone
- stage, validate and publish could be 3 different scripts that can be run separately.
- publish can take db name to apply changes to. It'd give an opportunity to apply changes on new db or cloned db (there is a cheap way to get a clone. that reminds persistant data structs. in functional programming)
- does converting uuids from String to UUID will help performance of joins?
- add support for data_driver_annotations, resources and study tags
- test mutsig. I did not find data to test it
