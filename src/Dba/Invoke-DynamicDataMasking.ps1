function Invoke-DynamicDataMasking {
    <#
.SYNOPSIS
A PowerShell function to apply data masks to database columns using the SQL Server dynamic data masking feature.

.DESCRIPTION
This function uses the information stored in the extended properties of a database:
sys.extended_properties.name = 'DATAMASK' to obtain the dynamic data masking function to apply
at column level. Columns of the following data type are currently supported:

- int
- bigint
- char
- nchar
- varchar
- nvarchar

Using the c_address column in the tpch customer table as an example, the DATAMASK extended property can be applied
to the column as follows:

exec sp_addextendedproperty
     @name = N'DATAMASK'
    ,@value = N'(FUNCTION = 'partial(0, "XX", 20)''
    ,@level0type = N'Schema', @level0name = 'dbo'
    ,@level1type = N'Table',  @level1name = 'customer'
    ,@level2type = N'Column', @level2name = 'c_address'
GO

.PARAMETER SqlInstance
Required. The SQL Server instance of the database that data masking is to be applied to.

.PARAMETER Database
Required. The database that data masking is to be applied to.

.EXAMPLE
Invoke-DynamicDataMasking -SqlInstance Z-STN-WIN2016-A\DEVOPSDEV -Database tpch-no-compression

.NOTES
Note that it has dependencies on the dbatools and PureStoragePowerShellSDK  modules which are installed as part of this module.
#>
	[CmdletBinding()]
    param(
        [parameter(mandatory = $true)][Sqlcollaborative.Dbatools.Parameter.DbaInstanceParameter] $SqlInstance,
        [parameter(mandatory = $true)][string] $Database,
		[parameter(mandatory = $false)][pscredential] $SqlCredential
    )

    $sql = @"
BEGIN
	DECLARE  @sql_statement nvarchar(1024)
	        ,@error_message varchar(1024)

	DECLARE apply_data_masks CURSOR FOR
	SELECT       'ALTER TABLE ' + tb.name + ' ALTER COLUMN ' + c.name +
			   + ' ADD MASKED WITH '
			   + CAST(p.value AS char) + ''')'
	FROM       sys.columns c
	JOIN       sys.types t
	ON         c.user_type_id = t.user_type_id
	LEFT JOIN  sys.index_columns ic
	ON         ic.object_id = c.object_id
	AND        ic.column_id = c.column_id
	LEFT JOIN  sys.indexes i
	ON         ic.object_id = i.object_id
	AND        ic.index_id  = i.index_id
	JOIN       sys.tables tb
	ON         tb.object_id = c.object_id
	JOIN       sys.extended_properties AS p
	ON         p.major_id   = tb.object_id
	AND        p.minor_id   = c.column_id
	AND        p.class      = 1
	WHERE      t.name IN ('int', 'bigint', 'char', 'nchar', 'varchar', 'nvarchar');

	OPEN apply_data_masks
	FETCH NEXT FROM apply_data_masks INTO @sql_statement;

	WHILE @@FETCH_STATUS = 0
	BEGIN
	    PRINT 'Applying data mask: ' + @sql_statement;

		BEGIN TRY
		    EXEC sp_executesql @stmt = @sql_statement
		END TRY
		BEGIN CATCH
		    SELECT @error_message = ERROR_MESSAGE();
			PRINT 'Application of data mask failed with: ' + @error_message;
		END CATCH;

		FETCH NEXT FROM apply_data_masks INTO @sql_statement
	END;

	CLOSE apply_data_masks
	DEALLOCATE apply_data_masks;
END;
"@

    Invoke-DbaQuery -Query $sql @PSBoundParameters
}