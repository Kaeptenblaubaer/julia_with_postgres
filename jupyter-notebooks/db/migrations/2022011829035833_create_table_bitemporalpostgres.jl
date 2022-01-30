module CreateTableBitemporalPostgres

import SearchLight.Migrations: create_table, column, columns, primary_key, add_index, drop_table, add_indices
import SearchLight.query
using SearchLight, TimeZones

createTsrTriggerFun = """
  CREATE OR REPLACE FUNCTION f_bitempranges ()
  RETURNS trigger AS
  \$\$
       DECLARE
  
       BEGIN
            RAISE NOTICE 'NEW: %', NEW;
            NEW.tsrworld := tstzrange(NEW.tsworld_validfrom,NEW.tsworld_invalidfrom,'[)');
            NEW.tsrdb := tstzrange(NEW.tsdb_validfrom,NEW.tsdb_invalidfrom,'[)');
            RETURN NEW;
       END;
  \$\$ LANGUAGE 'plpgsql';
  """
  createBitempTrigger = """
  CREATE TRIGGER versions_trig
  BEFORE INSERT OR UPDATE ON validityIntervals
  FOR EACH ROW EXECUTE PROCEDURE f_bitempranges();
  """
  createVersionsTriggerFun = """
  CREATE OR REPLACE FUNCTION f_versionrange ()
  RETURNS trigger AS
  \$\$
       DECLARE
  
       BEGIN
            RAISE NOTICE 'NEW: %', NEW;
            NEW.ref_valid := int8range(NEW.ref_validfrom,NEW.ref_invalidfrom,'[)');
            RETURN NEW;
       END;
  \$\$ LANGUAGE 'plpgsql';
  """

function up()
  createGistExtension = "CREATE EXTENSION IF NOT EXISTS btree_gist;"
  
  createValidityIntervalsConstraints = """
  ALTER TABLE validityIntervals 
  ADD CONSTRAINT bitemp EXCLUDE USING GIST (ref_version WITH =, is_committed WITH =, tsrworld WITH &&, tsrdb WITH &&)
  """

  create_table(:histories) do
    [
      column(:id,:bigserial,"PRIMARY KEY")
      column(:dummy, :integer)
    ]
  end

  create_table(:versions) do
    [
      column(:id,:bigserial,"PRIMARY KEY")
      column(:ref_history, :integer,"REFERENCES histories(id) ON DELETE CASCADE")
    ]
  end

  create_table(:validityIntervals) do
      [
        column(:id,:bigserial,"PRIMARY KEY")
        column(:ref_history, :integer,"REFERENCES histories(id) ON DELETE CASCADE")
        column(:ref_version, :integer,"REFERENCES versions(id) ON DELETE CASCADE")
        column(:tsworld_validfrom, :timestamptz)
        column(:tsworld_invalidfrom, :timestamptz)
        column(:tsdb_validfrom, :timestamptz)
        column(:tsdb_invalidfrom, :timestamptz)
        column(:tsrworld, :tstzrange)
        column(:tsrdb, :tstzrange) 
        column(:is_committed, :integer)
      ]
  end

  create_table(:contracts) do
    [
      column(:id,:bigserial,"PRIMARY KEY")
      column(:ref_history, :integer,"REFERENCES histories(id) ON DELETE CASCADE")
    ]
  end
  
  create_table(:contractRevisions) do
  [
    column(:id,:bigserial,"PRIMARY KEY")
    column(:ref_component, :integer, "REFERENCES contracts(id) ON DELETE CASCADE")
    column(:ref_validfrom, :integer, "REFERENCES versions(id) ON DELETE CASCADE")
    column(:ref_invalidfrom, :integer, "REFERENCES versions(id) ON DELETE CASCADE")
    column(:ref_valid, :int8range)
    column(:description, :string)
  ]
  end

  createContractRevisionsTrigger = """
  CREATE TRIGGER cr_versions_trig
  BEFORE INSERT OR UPDATE ON contractRevisions
  FOR EACH ROW EXECUTE PROCEDURE f_versionrange();
  """

  createContractRevisionsConstraints = """
  ALTER TABLE contractRevisions 
  ADD CONSTRAINT contractsversionrange EXCLUDE USING GIST (ref_component WITH =, ref_valid WITH &&)
  """    

  create_table(:partners) do
  [
    column(:id,:bigserial,"PRIMARY KEY")
    column(:ref_history, :integer,"REFERENCES histories(id) ON DELETE CASCADE")
  ]
  end

  create_table(:partnerRevisions) do
    [
      column(:id,:bigserial,"PRIMARY KEY")
      column(:ref_component, :integer, "REFERENCES partners(id) ON DELETE CASCADE")
      column(:ref_validfrom, :integer, "REFERENCES versions(id) ON DELETE CASCADE")
      column(:ref_invalidfrom, :integer, "REFERENCES versions(id) ON DELETE CASCADE")
      column(:ref_valid, :int8range)
      column(:description, :string)
    ]
  end

  createPartnerRevisionsTrigger = """
  CREATE TRIGGER pr_versions_trig
  BEFORE INSERT OR UPDATE ON partnerRevisions
  FOR EACH ROW EXECUTE PROCEDURE f_versionrange();
  """

  createPartnerRevisionsConstraints = """
  ALTER TABLE partnerRevisions 
  ADD CONSTRAINT partnersversionrange EXCLUDE USING GIST (ref_component WITH =, ref_valid WITH &&)
  """

  create_table(:testdummyComponents) do
    [
      column(:id,:bigserial,"PRIMARY KEY")
      column(:ref_history, :integer,"REFERENCES histories(id) ON DELETE CASCADE")
    ]
    end
  
    create_table(:testdummyComponentRevisions) do
      [
        column(:id,:bigserial,"PRIMARY KEY")
        column(:ref_component, :integer, "REFERENCES testdummyComponents(id) ON DELETE CASCADE")
        column(:ref_validfrom, :integer, "REFERENCES versions(id) ON DELETE CASCADE")
        column(:ref_invalidfrom, :integer, "REFERENCES versions(id) ON DELETE CASCADE")
        column(:ref_valid, :int8range)
        column(:description, :string)
      ]
    end
  
    createTestdummyComponentRevisionsTrigger = """
    CREATE TRIGGER tr_versions_trig
    BEFORE INSERT OR UPDATE ON testdummyComponentRevisions
    FOR EACH ROW EXECUTE PROCEDURE f_versionrange();
    """
  
    createTestdummyComponentRevisionsConstraints = """
    ALTER TABLE testdummycomponentrevisions 
    ADD CONSTRAINT testdummysversionrange EXCLUDE USING GIST (ref_component WITH =, ref_valid WITH &&)
    """

SearchLight.query(createGistExtension)
SearchLight.query(createValidityIntervalsConstraints)
SearchLight.query(createTsrTriggerFun)
SearchLight.query(createBitempTrigger)
SearchLight.query(createVersionsTriggerFun)
SearchLight.query(createContractRevisionsTrigger)
SearchLight.query(createContractRevisionsConstraints)
SearchLight.query(createPartnerRevisionsTrigger)
SearchLight.query(createPartnerRevisionsConstraints)
SearchLight.query(createTestdummyComponentRevisionsTrigger)
SearchLight.query(createTestdummyComponentRevisionsConstraints)
maxDate =  ZonedDateTime(DateTime(2038, 1, 19,14,7), tz"UTC")
maxDateSQL = SQLInput(maxDate)
infinityKey = 9223372036854775807 ::Integer

SearchLight.query("""
INSERT INTO histories VALUES($infinityKey,0)
"""
)
SearchLight.query("""
INSERT INTO versions VALUES($infinityKey)
"""
)
  
end

function down()
  drop_table(:testdummyComponentRevisions)
  drop_table(:testdummyComponents)
  drop_table(:contractRevisions)
  drop_table(:contracts)
  drop_table(:partnerRevisions)
  drop_table(:partners)
  drop_table(:validityIntervals)
  drop_table(:versions)
  drop_table(:histories)
end

end