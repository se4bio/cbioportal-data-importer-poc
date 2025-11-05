# New cBioPortal data importer POC

## Issues with the current importer

Current cBioPortal importer (`cbioportal-core`) has a number of other potential issues beyond technical complexity and slowness that we should be aware of while implementing the new importer.

Not all improvements can be achieved within the scope of RFC100, but we should avoid decisions that would make future improvements more difficult.

### Shared database schema as an “API” between importer and cBioPortal web app

Our current schema is in flux. As a community, we are still exploring what the optimal schema should be to take full advantage of column-based databases like ClickHouse. This process will take time and involve multiple iterations.

When the database schema is shared between the importer and the web app, any schema redesign becomes more difficult, as both projects—the web application and the importer transformations—must be updated simultaneously.
On the deployment side, each version of the importer must match the corresponding version of cBioPortal to ensure compatibility after every schema change.

The situation becomes even more complex if the schema is also exposed to importer users. In that case, users could supply data files matching the schema directly, alongside the current cBioPortal flat file format.
Exposing the schema to users introduces versioning challenges—we would need to either enforce strict backward compatibility or provide migration scripts for all schema versions.
(We’ll need to handle schema migrations within the database anyway, so this would duplicate that effort.)

### Two versions of business logic

Beyond the shared schema, which enforces data shape and types, additional business logic (e.g., data constraints) must also be implemented in code.
This creates the risk of maintaining two versions of the same logic: one in the importer and another in the web application. And they can mismatch.

### Unconditional access rights

The importer currently has unrestricted access to the shared schema—and with great power comes great responsibility.
Some of these permissions (such as dropping tables) can and should be revoked at the database user level.
However, it’s much harder to enforce domain-specific sanity checks at this level. For example:

Loading a new study should not affect data from existing studies.

Application-specific authorization rules cannot easily be enforced within the database.

These limitations and risks become particularly apparent in a multi-organizational cBioPortal instance, where multiple data owners may upload their data independently.

### Concurrent imports

The current importer only partially supports concurrent imports—they are possible when transactions span multiple data type uploads.
In the future, concurrent imports will likely become more important, as multiple data managers may need to upload data to the same instance simultaneously.

## How the Approach in This POC Addresses the Issues

I built this proof of concept (POC) to load data into a **staging zone** within the database, applying only minimal transformations — following an **ELT-style** pattern.  
All major transformations (the *publish* step) will eventually be executed by **cBioPortal**, and the importer itself will remain schema-agnostic.

---

### Easier Schema Changes
- The **staging** schema (stable) and **production** schema (subject to change) are separated.  
- When production schema changes occur, **no modifications** to the importer are required.

---

### Single Source of Business Logic
- The **publishing** will be part of the web application and reuse the **business logic already implemented** there.

---

### No Direct or Uncontrolled Data Modifications
- The importer will **not write directly** to production tables.  
- All transformations and data validation will happen during the **publishing phase** within cBioPortal, ensuring that operations are authorised and make sense.

---

### Safe Concurrent Execution
- The **staging process** can run concurrently and in parallel without issues.  
- **Validation and publishing** steps will be **queued** and executed sequentially to maintain data integrity.


## Run

1. Copy `.env.example` file to `.env` and modify it according with your DB creds.
2. Stage study(ies)

```bash
./stage.sh ../path/to/study_folder/
```

This command loads all found meta and data files to the staging database. The command also creates such database if not exists.

3. Publish staged data.

```bash
./publish.sh <change set uuid>
```

This commands moves all data from staging zone to production tables.

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

