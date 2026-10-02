<?php
declare(strict_types=1);

final class PhoneController
{
    private const METHODS=['cash','transfer','qris'];

    public static function index(): never
    {
        $status=trim((string)($_GET['status']??''));$search=trim((string)($_GET['search']??''));
        $sql='SELECT * FROM phones WHERE deleted_at IS NULL';$p=[];
        if($status!==''){if(!in_array($status,['available','sold'],true))Response::error('Status HP tidak valid.',422);$sql.=' AND phone_status=:status';$p['status']=$status;}
        if($search!==''){$like='%'.$search.'%';$sql.=' AND (phone_code LIKE :q1 OR device_name LIKE :q2 OR seller_name LIKE :q3 OR source_name LIKE :q4)';$p['q1']=$like;$p['q2']=$like;$p['q3']=$like;$p['q4']=$like;}
        $sql.=' ORDER BY purchase_date DESC,created_at DESC LIMIT 500';$s=Database::connection()->prepare($sql);$s->execute($p);Response::success(['phones'=>$s->fetchAll()]);
    }

    public static function show(string $id): never { Response::success(['phone'=>self::find($id)]); }

    public static function storePurchase(): never
    {
        $d=Request::json();self::validateBase($d);$id=isset($d['id'])&&Uuid::valid((string)$d['id'])?(string)$d['id']:Uuid::v4();$now=self::date($d['purchase_date']??null);$code=trim((string)($d['phone_code']??''))?:self::code();
        if(isset($d['id'])&&Uuid::valid((string)$d['id'])&&self::exists(Database::connection(),$id))Response::success(['phone'=>self::find($id)],'Pembelian HP sudah tersimpan.');
        try{$s=Database::connection()->prepare('INSERT INTO phones (id,phone_code,device_name,acquisition_type,phone_status,purchase_price,selling_price,condition_notes,accessories,seller_name,source_name,purchase_date,notes,created_at,updated_at) VALUES (:id,:code,:device,\'stock\',\'available\',:purchase_price,:selling_price,:condition_notes,:accessories,:seller_name,:source_name,:purchase_date,:notes,:created_at,:updated_at)');
            $s->execute(['id'=>$id,'code'=>$code,'device'=>trim((string)$d['device_name']),'purchase_price'=>(float)$d['purchase_price'],'selling_price'=>self::moneyOrNull($d['selling_price']??null),'condition_notes'=>self::null($d['condition_notes']??null),'accessories'=>self::null($d['accessories']??null),'seller_name'=>self::null($d['seller_name']??null),'source_name'=>self::null($d['source_name']??null),'purchase_date'=>$now,'notes'=>self::null($d['notes']??null),'created_at'=>$now,'updated_at'=>$now]);Response::success(['phone'=>self::find($id)],'Pembelian HP berhasil dicatat.',201);
        }catch(Throwable $e){self::fail($e);}
    }

    public static function sell(string $id): never
    {
        $d=Request::json();self::validateSale($d);$pdo=Database::connection();
        try{$pdo->beginTransaction();$phone=self::lock($pdo,$id);$selling=(float)$d['selling_price'];
            if($phone['phone_status']!=='available'){throw new DomainException('HP sudah terjual');}
            $soldAt=self::date($d['sale_date']??null);$w=self::warranty($d,$soldAt);
            $pdo->prepare('UPDATE phones SET phone_status=\'sold\',selling_price=:selling,profit=:profit,sale_date=:sale_date,payment_method=:method,source_name=:source_name,warranty_value=:wv,warranty_unit=:wu,warranty_started_at=:ws,warranty_ends_at=:we,notes=:notes,updated_at=:updated_at WHERE id=:id')->execute(['selling'=>$selling,'profit'=>$selling-(float)$phone['purchase_price'],'sale_date'=>$soldAt,'method'=>$d['payment_method'],'source_name'=>self::null($d['source_name']??$phone['source_name']),'wv'=>$w['value'],'wu'=>$w['unit'],'ws'=>$w['start'],'we'=>$w['end'],'notes'=>self::null($d['notes']??$phone['notes']),'updated_at'=>$soldAt,'id'=>$id]);$pdo->commit();Response::success(['phone'=>self::find($id)],'Penjualan HP berhasil dicatat.');
        }catch(Throwable $e){if($pdo->inTransaction())$pdo->rollBack();self::fail($e);}
    }

    public static function directSale(): never
    {
        $d=Request::json();self::validateBase($d);self::validateSale($d);$id=isset($d['id'])&&Uuid::valid((string)$d['id'])?(string)$d['id']:Uuid::v4();$soldAt=self::date($d['sale_date']??null);$purchaseAt=self::date($d['purchase_date']??$soldAt);$code=trim((string)($d['phone_code']??''))?:self::code();$w=self::warranty($d,$soldAt);$buy=(float)$d['purchase_price'];$sell=(float)$d['selling_price'];
        try{$s=Database::connection()->prepare('INSERT INTO phones (id,phone_code,device_name,acquisition_type,phone_status,purchase_price,selling_price,profit,condition_notes,accessories,seller_name,source_name,purchase_date,sale_date,payment_method,warranty_value,warranty_unit,warranty_started_at,warranty_ends_at,notes,created_at,updated_at) VALUES (:id,:code,:device,\'direct\',\'sold\',:buy,:sell,:profit,:condition_notes,:accessories,:seller_name,:source_name,:purchase_date,:sale_date,:method,:wv,:wu,:ws,:we,:notes,:created_at,:updated_at)');
            $s->execute(['id'=>$id,'code'=>$code,'device'=>trim((string)$d['device_name']),'buy'=>$buy,'sell'=>$sell,'profit'=>$sell-$buy,'condition_notes'=>self::null($d['condition_notes']??null),'accessories'=>self::null($d['accessories']??null),'seller_name'=>self::null($d['seller_name']??null),'source_name'=>self::null($d['source_name']??null),'purchase_date'=>$purchaseAt,'sale_date'=>$soldAt,'method'=>$d['payment_method'],'wv'=>$w['value'],'wu'=>$w['unit'],'ws'=>$w['start'],'we'=>$w['end'],'notes'=>self::null($d['notes']??null),'created_at'=>$soldAt,'updated_at'=>$soldAt]);Response::success(['phone'=>self::find($id)],'Penjualan HP langsung berhasil dicatat.',201);
        }catch(Throwable $e){self::fail($e);}
    }

    public static function update(string $id): never
    {
        $old=self::find($id);if($old['phone_status']!=='available')Response::error('HP terjual tidak bisa diedit melalui form stok.',422);$d=array_merge($old,Request::json());self::validateBase($d);$now=gmdate('Y-m-d H:i:s');
        try{$s=Database::connection()->prepare('UPDATE phones SET phone_code=:code,device_name=:device,purchase_price=:buy,selling_price=:selling_price,condition_notes=:condition_notes,accessories=:accessories,seller_name=:seller_name,source_name=:source_name,purchase_date=:purchase_date,notes=:notes,updated_at=:updated_at WHERE id=:id AND deleted_at IS NULL AND phone_status=\'available\'');$s->execute(['code'=>trim((string)$d['phone_code']),'device'=>trim((string)$d['device_name']),'buy'=>(float)$d['purchase_price'],'selling_price'=>self::moneyOrNull($d['selling_price']??null),'condition_notes'=>self::null($d['condition_notes']??null),'accessories'=>self::null($d['accessories']??null),'seller_name'=>self::null($d['seller_name']??null),'source_name'=>self::null($d['source_name']??null),'purchase_date'=>self::date($d['purchase_date']),'notes'=>self::null($d['notes']??null),'updated_at'=>$now,'id'=>$id]);Response::success(['phone'=>self::find($id)],'Data HP berhasil diperbarui.');}
        catch(Throwable $e){self::fail($e);}
    }

    public static function destroy(string $id): never
    {
        self::find($id);$now=gmdate('Y-m-d H:i:s');$s=Database::connection()->prepare('UPDATE phones SET deleted_at=:deleted_at,updated_at=:updated_at WHERE id=:id');$s->execute(['deleted_at'=>$now,'updated_at'=>$now,'id'=>$id]);Response::success([],'Data HP berhasil dihapus.');
    }

    private static function warranty(array $d,string $start): array
    {
        if(!isset($d['warranty_value'])||$d['warranty_value']===''||$d['warranty_value']===null)return['value'=>null,'unit'=>null,'start'=>null,'end'=>null];$v=(int)$d['warranty_value'];$u=(string)($d['warranty_unit']??'');if($v<=0||!in_array($u,['hour','day'],true))throw new DomainException('Data garansi tidak valid.');$date=DateTimeImmutable::createFromFormat('!Y-m-d H:i:s',$start,new DateTimeZone('UTC'));if(!$date)throw new DomainException('Tanggal penjualan tidak valid.');return['value'=>$v,'unit'=>$u,'start'=>$start,'end'=>$date->modify('+'.$v.' '.$u)->format('Y-m-d H:i:s')];
    }

    private static function validateBase(array $d): void
    {$e=[];if(trim((string)($d['device_name']??''))==='')$e['device_name']='Merk dan model HP wajib diisi.';if(!isset($d['purchase_price'])||!is_numeric($d['purchase_price'])||(float)$d['purchase_price']<0)$e['purchase_price']='Harga beli/modal tidak valid.';if(isset($d['selling_price'])&&$d['selling_price']!==''&&$d['selling_price']!==null&&(!is_numeric($d['selling_price'])||(float)$d['selling_price']<0))$e['selling_price']='Harga jual target tidak valid.';if($e!==[])Response::error('Data HP belum valid.',422,$e);}

    private static function validateSale(array $d): void
    {$e=[];if(!isset($d['selling_price'])||!is_numeric($d['selling_price'])||(float)$d['selling_price']<0)$e['selling_price']='Harga jual tidak valid.';if(!in_array((string)($d['payment_method']??''),self::METHODS,true))$e['payment_method']='Metode pembayaran harus cash, transfer, atau qris.';if($e!==[])Response::error('Data penjualan HP belum valid.',422,$e);}

    private static function find(string $id): array
    {if(!Uuid::valid($id))Response::error('ID HP tidak valid.',422);$s=Database::connection()->prepare('SELECT * FROM phones WHERE id=:id AND deleted_at IS NULL LIMIT 1');$s->execute(['id'=>$id]);$r=$s->fetch();if(!$r)Response::error('Data HP tidak ditemukan.',404);return$r;}

    private static function lock(PDO $pdo,string $id): array
    {if(!Uuid::valid($id))throw new DomainException('ID HP tidak valid.');$s=$pdo->prepare('SELECT * FROM phones WHERE id=:id AND deleted_at IS NULL LIMIT 1 FOR UPDATE');$s->execute(['id'=>$id]);$r=$s->fetch();if(!$r)throw new DomainException('Data HP tidak ditemukan.');return$r;}

    private static function exists(PDO $pdo,string $id): bool
    {$s=$pdo->prepare('SELECT 1 FROM phones WHERE id=:id AND deleted_at IS NULL LIMIT 1');$s->execute(['id'=>$id]);return(bool)$s->fetchColumn();}

    private static function code(): string{return'HP-'.gmdate('Ymd').'-'.strtoupper(substr(str_replace('-','',Uuid::v4()),0,8));}
    private static function null(mixed $v): ?string{$v=trim((string)($v??''));return$v===''?null:$v;}
    private static function moneyOrNull(mixed $v): ?float{return$v===''||$v===null?null:(float)$v;}
    private static function date(mixed $v): string{if(!is_string($v)||trim($v)==='')return gmdate('Y-m-d H:i:s');$d=new DateTimeImmutable($v,new DateTimeZone('UTC'));return$d->setTimezone(new DateTimeZone('UTC'))->format('Y-m-d H:i:s');}
    private static function fail(Throwable $e): never{if($e instanceof DomainException)Response::error($e->getMessage(),422);if($e instanceof PDOException&&(string)$e->getCode()==='23000')Response::error('Kode HP atau ID sudah digunakan.',409);throw$e;}
}
