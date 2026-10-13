package db.migration;

import java.sql.*;
import java.util.*;
import org.flywaydb.core.api.migration.BaseJavaMigration;
import org.flywaydb.core.api.migration.Context;

/** Merge district records into cities without dropping profile or service associations. */
public class V59__CityWorkAreas extends BaseJavaMigration {
    private record Area(UUID id,String city,boolean recruiting,int capacity,long version) {}
    @Override public void migrate(Context context) throws Exception {
        var connection=context.getConnection();
        Map<String,List<Area>> cities=new LinkedHashMap<>();
        try(var statement=connection.createStatement();var rows=statement.executeQuery("SELECT id,city,recruiting,capacity,version FROM recruitment_areas ORDER BY id")) {
            while(rows.next()) {
                String city=rows.getString("city").trim();
                cities.computeIfAbsent(city.toLowerCase(Locale.ROOT),key->new ArrayList<>()).add(new Area(rows.getObject("id",UUID.class),city,rows.getBoolean("recruiting"),rows.getInt("capacity"),rows.getLong("version")));
            }
        }
        for(var group:cities.values()) {
            var keeper=group.getFirst();long capacity=0;boolean recruiting=false;
            for(var area:group) {
                capacity+=area.capacity();recruiting|=area.recruiting();
                if(area.id().equals(keeper.id()))continue;
                mergeLinks(connection,"partner_application_areas","application_id","area_id",area.id(),keeper.id());
                mergeLinks(connection,"recruitment_area_services","service_id","area_id",area.id(),keeper.id());
                try(var delete=connection.prepareStatement("DELETE FROM recruitment_areas WHERE id=?")){delete.setObject(1,area.id());delete.executeUpdate();}
            }
            try(var update=connection.prepareStatement("UPDATE recruitment_areas SET city=?,name=?,recruiting=?,capacity=?,version=version+1,updated_at=CURRENT_TIMESTAMP WHERE id=?")) {
                update.setString(1,keeper.city());update.setString(2,keeper.city());update.setBoolean(3,recruiting);update.setInt(4,(int)Math.min(100000,capacity));update.setObject(5,keeper.id());update.executeUpdate();
            }
        }
        String key=connection.getMetaData().getDatabaseProductName().equals("PostgreSQL")?"lower(btrim(city))":"city";
        try(var statement=connection.createStatement()){statement.execute("CREATE UNIQUE INDEX uq_recruitment_area_city ON recruitment_areas("+key+")");}
    }
    private void mergeLinks(Connection connection,String table,String owner,String areaColumn,UUID oldId,UUID cityId) throws Exception {
        List<UUID> owners=new ArrayList<>();
        try(var query=connection.prepareStatement("SELECT "+owner+" FROM "+table+" WHERE "+areaColumn+"=?")) {
            query.setObject(1,oldId);try(var rows=query.executeQuery()){while(rows.next())owners.add(rows.getObject(1,UUID.class));}
        }
        for(var id:owners) {
            try(var insert=connection.prepareStatement("INSERT INTO "+table+"("+owner+","+areaColumn+") SELECT ?,? WHERE NOT EXISTS (SELECT 1 FROM "+table+" WHERE "+owner+"=? AND "+areaColumn+"=?)")) {
                insert.setObject(1,id);insert.setObject(2,cityId);insert.setObject(3,id);insert.setObject(4,cityId);insert.executeUpdate();
            }
        }
        try(var delete=connection.prepareStatement("DELETE FROM "+table+" WHERE "+areaColumn+"=?")){delete.setObject(1,oldId);delete.executeUpdate();}
    }
}
