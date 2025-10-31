# cBioPortal data importer POC

It loads data to the staging zone in the database with minimal transformations to do the rest of operations there (kinda ELT)

## TODO
- **Test with more data types.**  
  For example, the `sample_id` column in protein-level data appears blank in the database.  
  - How can we detect and prevent such silent errors?  
    - One option: use `--input_format_allow_missing_columns=0`.  
      However, this requires cleaning up extra columns (e.g. “about”). That’s a good practice anyway.

- **Simplify the database schema.**  
  - Remove “staging” from table names — having a staging database is enough.  
  - Some columns (e.g. “others”) are not used; consider dropping them.

- **Test loading data to the cloud over the network.**  
  - Measure how much slower the importer becomes.  
  - If it’s significantly slower, try loading data with `clickhouse-local` first, then sending the native binary to the remote server.

- **Use parallel uploads.**  
  - Try running four parallel processes (e.g. with GNU Parallel) to upload data faster.

- **Document the importer setup.**  
  - Write clear instructions for external users on how to run the importer.

- **Create database validation examples.**  
  - Provide example queries or workflows for running data validations directly in the database.

- **Implement SQL for publishing data.**  
  - Define SQL scripts to move data from the staging zone to the production zone.

- **Split functionality into separate scripts.**  
  - Have three standalone scripts: `stage`, `validate`, and `publish`.

- **Make the publish step configurable.**  
  - Allow `publish` to take a database name as an argument.  
    This makes it possible to apply changes to a new or cloned database (cloning is cheap and conceptually similar to persistent data structures in functional programming).

- **Evaluate UUID performance.**  
  - Check if converting UUIDs from `String` to native `UUID` type improves join performance.

- **Add support for new data types.**  
  - Include support for `data_driver_annotations`, `resources`, and `study_tags`.

- **Test Mutsig integration.**  
  - Find or generate data to properly test Mutsig.

## IDEAS
- **Automate validation and publishing using materialized views (MVs).**  
  Each step could be triggered automatically when a new update is appended to the import status table.  
  Finishing one stage could trigger the next.

- **Add an API for managing batch imports and metadata.**  
  - The API should hide low-level details like batch/metadata UUID generation and updating the import status table.  
  - Example flow:
    1. **Start batch session:**  
       The client submits metadata in one request and receives all UUIDs (batch and meta).  
       Meta IDs can be linked to different URLs (e.g. to update clinical variable definitions or values separately).
    2. **Upload data files:**  
       The client uploads one file per URL + meta UUID.  
       Each file should follow a defined format (e.g. TSV or Parquet).  
       Multiple files per resource can be supported.  
       It may also be possible to extend resources without calling `start batch session` first; in that case, “finish” happens right after upload.
    3. **Finish batch session:**  
       Once uploads are done, the client calls `finish`.  
       This triggers validation and publishing.  
       The client can check progress using a status call.

