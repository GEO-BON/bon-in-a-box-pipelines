import pystac_client
import planetary_computer
import os


def get_taxa_gbif_pc(taxa=[], bbox=[], years=[1980,2025], outfile=''):
    catalog = pystac_client.Client.open(
        "https://planetarycomputer.microsoft.com/api/stac/v1",
    )

    try: 
        search = catalog.search(collections=["gbif"])
        items = search.get_all_items()
        items = {x.id: x for x in items}
        item = list(items.values())[0]

        signed_asset = planetary_computer.sign(item).assets["data"]

        filters=[]
        for t in taxa:
            filters.append([('species', '==', t), ('decimallatitude','<',float(bbox[3])), ('decimallatitude','>',float(bbox[1])), ('decimallongitude','>',float(bbox[0])), ('decimallongitude','<',float(bbox[2])), ('year','>',int(years[0])), ('year','<',int(years[1]))])
        
        
        df = dd.read_parquet(
            signed_asset.href,
            storage_options=signed_asset.extra_fields["table:storage_options"],
            filters=filters,
            columns=["gbifid","scientificname","decimallongitude","decimallatitude","year","month","day","basisofrecord","occurrencestatus"],
            arrow_to_pandas=dict(timestamp_as_object=True),
            parquet_file_extension=None,
            engine="pyarrow",
        )
        res=df.compute() 
        print(res)
        res.columns = (res.columns
                    .str.replace('(?<=[a-z])(?=[A-Z])', '_', regex=True).str.lower()
                )
        res = res.rename(columns={'gbidid':'id','decimallatitude': 'decimal_latitude', 'decimallongitude':'decimal_longtitude'})

        res.to_csv(outfile, sep ='\t')
    except Exception as inst:
        print('Something went wrong')
        print(type(inst))
        raise


    return({'outfile':outfile, 'total_records': len(df), 'doi': '' })

