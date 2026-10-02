<?php
declare(strict_types=1);

final class ExpenseController
{
    public static function index(): never
    {
        $from=self::filterDate($_GET['from']??null,false);$to=self::filterDate($_GET['to']??null,true);$search=trim((string)($_GET['search']??''));
        $sql='SELECT * FROM expenses WHERE deleted_at IS NULL';$p=[];
        if($from!==null){$sql.=' AND expense_date>=:date_from';$p['date_from']=$from;}
        if($to!==null){$sql.=' AND expense_date<=:date_to';$p['date_to']=$to;}
        if($search!==''){$like='%'.$search.'%';$sql.=' AND (expense_category LIKE :q1 OR expense_name LIKE :q2 OR notes LIKE :q3)';$p['q1']=$like;$p['q2']=$like;$p['q3']=$like;}
        $sql.=' ORDER BY expense_date DESC,created_at DESC LIMIT 500';$s=Database::connection()->prepare($sql);$s->execute($p);
        Response::success(['expenses'=>$s->fetchAll()]);
    }

    public static function show(string $id): never { Response::success(['expense'=>self::find($id)]); }

    public static function store(): never
    {
        $d=Request::json();self::validate($d);$id=isset($d['id'])&&Uuid::valid((string)$d['id'])?(string)$d['id']:Uuid::v4();$date=self::date($d['expense_date']??null);$now=gmdate('Y-m-d H:i:s');
        try{$s=Database::connection()->prepare('INSERT INTO expenses (id,expense_category,expense_name,amount,expense_date,notes,created_at,updated_at) VALUES (:id,:category,:name,:amount,:expense_date,:notes,:created_at,:updated_at)');$s->execute(['id'=>$id,'category'=>trim((string)$d['expense_category']),'name'=>trim((string)$d['expense_name']),'amount'=>(float)$d['amount'],'expense_date'=>$date,'notes'=>self::null($d['notes']??null),'created_at'=>$now,'updated_at'=>$now]);Response::success(['expense'=>self::find($id)],'Pengeluaran berhasil dicatat.',201);}
        catch(Throwable $e){self::fail($e);}
    }

    public static function update(string $id): never
    {
        $old=self::find($id);$d=array_merge($old,Request::json());self::validate($d);$now=gmdate('Y-m-d H:i:s');
        try{$s=Database::connection()->prepare('UPDATE expenses SET expense_category=:category,expense_name=:name,amount=:amount,expense_date=:expense_date,notes=:notes,updated_at=:updated_at WHERE id=:id AND deleted_at IS NULL');$s->execute(['category'=>trim((string)$d['expense_category']),'name'=>trim((string)$d['expense_name']),'amount'=>(float)$d['amount'],'expense_date'=>self::date($d['expense_date']),'notes'=>self::null($d['notes']??null),'updated_at'=>$now,'id'=>$id]);Response::success(['expense'=>self::find($id)],'Pengeluaran berhasil diperbarui.');}
        catch(Throwable $e){self::fail($e);}
    }

    public static function destroy(string $id): never
    {
        self::find($id);$now=gmdate('Y-m-d H:i:s');$s=Database::connection()->prepare('UPDATE expenses SET deleted_at=:deleted_at,updated_at=:updated_at WHERE id=:id');$s->execute(['deleted_at'=>$now,'updated_at'=>$now,'id'=>$id]);Response::success([],'Pengeluaran berhasil dihapus.');
    }

    private static function find(string $id): array
    {if(!Uuid::valid($id))Response::error('ID pengeluaran tidak valid.',422);$s=Database::connection()->prepare('SELECT * FROM expenses WHERE id=:id AND deleted_at IS NULL LIMIT 1');$s->execute(['id'=>$id]);$r=$s->fetch();if(!$r)Response::error('Pengeluaran tidak ditemukan.',404);return$r;}

    private static function validate(array $d): void
    {$e=[];if(trim((string)($d['expense_category']??''))==='')$e['expense_category']='Kategori pengeluaran wajib diisi.';if(trim((string)($d['expense_name']??''))==='')$e['expense_name']='Keterangan pengeluaran wajib diisi.';if(!isset($d['amount'])||!is_numeric($d['amount'])||(float)$d['amount']<=0)$e['amount']='Nominal harus lebih dari nol.';if(isset($d['id'])&&!Uuid::valid((string)$d['id']))$e['id']='ID pengeluaran tidak valid.';if($e!==[])Response::error('Data pengeluaran belum valid.',422,$e);}

    private static function filterDate(mixed $v,bool $end): ?string
    {$v=trim((string)($v??''));if($v==='')return null;try{$d=new DateTimeImmutable($v,new DateTimeZone('UTC'));}catch(Throwable){Response::error('Filter tanggal tidak valid.',422);}return preg_match('/^\d{4}-\d{2}-\d{2}$/',$v)===1?$d->format('Y-m-d').($end?' 23:59:59':' 00:00:00'):$d->format('Y-m-d H:i:s');}
    private static function date(mixed $v): string{if(!is_string($v)||trim($v)==='')return gmdate('Y-m-d H:i:s');$d=new DateTimeImmutable($v,new DateTimeZone('UTC'));return$d->setTimezone(new DateTimeZone('UTC'))->format('Y-m-d H:i:s');}
    private static function null(mixed $v): ?string{$v=trim((string)($v??''));return$v===''?null:$v;}
    private static function fail(Throwable $e): never{if($e instanceof PDOException&&(string)$e->getCode()==='23000')Response::error('ID pengeluaran sudah digunakan.',409);throw$e;}
}
