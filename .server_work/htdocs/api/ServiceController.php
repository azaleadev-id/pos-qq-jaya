<?php
declare(strict_types=1);

final class ServiceController
{
    private const STATUSES = ['in','waiting','working','completed'];
    private const METHODS = ['cash','transfer','qris'];

    public static function index(): never
    {
        $status=trim((string)($_GET['status']??'')); $search=trim((string)($_GET['search']??''));
        $sql='SELECT * FROM services WHERE deleted_at IS NULL'; $p=[];
        if($status!==''){if(!in_array($status,self::STATUSES,true))Response::error('Status servis tidak valid.',422);$sql.=' AND service_status=:status';$p['status']=$status;}
        if($search!==''){$sql.=' AND (service_number LIKE :q1 OR device_name LIKE :q2 OR service_name LIKE :q3 OR customer_name LIKE :q4 OR customer_whatsapp LIKE :q5)';$like='%'.$search.'%';$p+=['q1'=>$like,'q2'=>$like,'q3'=>$like,'q4'=>$like,'q5'=>$like];}
        $sql.=' ORDER BY received_at DESC,created_at DESC LIMIT 500';
        $s=Database::connection()->prepare($sql);$s->execute($p);Response::success(['services'=>$s->fetchAll()]);
    }

    public static function show(string $id): never { Response::success(self::detail($id)); }

    public static function presets(): never
    {
        $q=trim((string)($_GET['search']??''));$sql='SELECT * FROM service_presets WHERE deleted_at IS NULL AND is_active=1';$p=[];
        if($q!==''){$sql.=' AND (device_name LIKE :q1 OR service_name LIKE :q2)';$like='%'.$q.'%';$p=['q1'=>$like,'q2'=>$like];}
        $sql.=' ORDER BY updated_at DESC LIMIT 100';$s=Database::connection()->prepare($sql);$s->execute($p);
        Response::success(['presets'=>$s->fetchAll()]);
    }

    public static function store(): never
    {
        $d=Request::json();self::validate($d);$pdo=Database::connection();
        $id=isset($d['id'])&&Uuid::valid((string)$d['id'])?(string)$d['id']:Uuid::v4();
        if(isset($d['id'])&&Uuid::valid((string)$d['id'])&&self::exists($pdo,$id))Response::success(self::detail($id),'Servis sudah tersimpan.');
        try{$pdo->beginTransaction();self::write($pdo,$id,$d,false);$status=(string)($d['service_status']??'in');self::history($pdo,$id,null,$status,self::date($d['received_at']??null));
            if(isset($d['initial_payment'])&&(float)$d['initial_payment']>0)self::payment($pdo,$id,['amount'=>$d['initial_payment'],'payment_method'=>$d['payment_method']??'','payment_type'=>$d['payment_type']??'down_payment','paid_at'=>$d['received_at']??null,'notes'=>'Pembayaran awal servis']);
            self::preset($pdo,$id);$pdo->commit();Response::success(self::detail($id),'Servis berhasil diterima.',201);
        }catch(Throwable $e){if($pdo->inTransaction())$pdo->rollBack();self::fail($e);}
    }

    public static function update(string $id): never
    {
        $current=self::find($id);$d=array_merge($current,Request::json());self::validate($d);$pdo=Database::connection();
        try{$pdo->beginTransaction();$locked=self::lock($pdo,$id);$d['service_number']=$locked['service_number'];$d['service_status']=$locked['service_status'];self::write($pdo,$id,$d,true);self::totals($pdo,$id);self::preset($pdo,$id);$pdo->commit();Response::success(self::detail($id),'Data servis berhasil diperbarui.');}
        catch(Throwable $e){if($pdo->inTransaction())$pdo->rollBack();self::fail($e);}
    }

    public static function changeStatus(string $id): never
    {
        $d=Request::json();$new=(string)($d['status']??'');if(!in_array($new,self::STATUSES,true))Response::error('Status servis tidak valid.',422);$pdo=Database::connection();
        try{$pdo->beginTransaction();$s=self::lock($pdo,$id);$old=$s['service_status'];
            $now=self::date($d['changed_at']??null);$wdata=$d;
            if($new==='completed'&&!isset($wdata['warranty_value'])&&$s['warranty_value']!==null){$wdata['warranty_value']=$s['warranty_value'];$wdata['warranty_unit']=$s['warranty_unit'];}
            $w=self::warranty($wdata,$new==='completed'?$now:null);
            $pdo->prepare('UPDATE services SET service_status=:status,completed_at=:completed,warranty_value=:wv,warranty_unit=:wu,warranty_started_at=:ws,warranty_ends_at=:we,updated_at=:now WHERE id=:id')->execute([
                'status'=>$new,'completed'=>$new==='completed'?$now:$s['completed_at'],'wv'=>$w['value']??$s['warranty_value'],'wu'=>$w['unit']??$s['warranty_unit'],'ws'=>$w['start']??$s['warranty_started_at'],'we'=>$w['end']??$s['warranty_ends_at'],'now'=>$now,'id'=>$id]);
            if($new!==$old)self::history($pdo,$id,$old,$new,$now);$pdo->commit();Response::success(self::detail($id),'Status servis berhasil diubah.');
        }catch(Throwable $e){if($pdo->inTransaction())$pdo->rollBack();self::fail($e);}
    }

    public static function addPayment(string $id): never
    {
        $d=Request::json();$pdo=Database::connection();try{$pdo->beginTransaction();self::lock($pdo,$id);self::payment($pdo,$id,$d);self::totals($pdo,$id);$pdo->commit();Response::success(self::detail($id),'Pembayaran servis berhasil dicatat.',201);}
        catch(Throwable $e){if($pdo->inTransaction())$pdo->rollBack();self::fail($e);}
    }

    public static function destroy(string $id): never
    {
        self::find($id);$pdo=Database::connection();$now=gmdate('Y-m-d H:i:s');
        try{$pdo->beginTransaction();
            $pdo->prepare('UPDATE service_payments SET deleted_at=:deleted_at,updated_at=:updated_at WHERE service_id=:id AND deleted_at IS NULL')->execute(['deleted_at'=>$now,'updated_at'=>$now,'id'=>$id]);
            $pdo->prepare('UPDATE services SET deleted_at=:deleted_at,updated_at=:updated_at WHERE id=:id')->execute(['deleted_at'=>$now,'updated_at'=>$now,'id'=>$id]);
            $pdo->commit();Response::success([],'Data servis berhasil dihapus.');
        }catch(Throwable $e){if($pdo->inTransaction())$pdo->rollBack();self::fail($e);}
    }

    private static function write(PDO $pdo,string $id,array $d,bool $edit): void
    {
        $now=self::date($d['updated_at']??null);$price=(float)$d['service_price'];$parts=(float)($d['parts_cost']??0);$delivery=(float)($d['delivery_cost']??0);$invoice=$price+$delivery;$cost=$parts+$delivery;
        $warrantyValue=isset($d['warranty_value'])&&$d['warranty_value']!==''&&$d['warranty_value']!==null?(int)$d['warranty_value']:null;$warrantyUnit=$warrantyValue===null?null:(string)($d['warranty_unit']??'hour');
        $base=['id'=>$id,'customer_name'=>self::null($d['customer_name']??null),'customer_whatsapp'=>self::null($d['customer_whatsapp']??null),'customer_address'=>self::null($d['customer_address']??null),'device_name'=>trim((string)$d['device_name']),'service_name'=>trim((string)$d['service_name']),'color'=>self::null($d['color']??null),'accessories'=>self::null($d['accessories']??null),'service_price'=>$price,'parts_cost'=>$parts,'delivery_cost'=>$delivery,'total_cost'=>$cost,'profit'=>$invoice-$cost,'warranty_value'=>$warrantyValue,'warranty_unit'=>$warrantyUnit,'received_at'=>self::date($d['received_at']??null),'now'=>$now];
        if($edit){$sql='UPDATE services SET customer_name=:customer_name,customer_whatsapp=:customer_whatsapp,customer_address=:customer_address,device_name=:device_name,service_name=:service_name,color=:color,accessories=:accessories,service_price=:service_price,parts_cost=:parts_cost,delivery_cost=:delivery_cost,total_cost=:total_cost,profit=:profit,warranty_value=:warranty_value,warranty_unit=:warranty_unit,received_at=:received_at,updated_at=:now WHERE id=:id AND deleted_at IS NULL';}
        else{$base['number']=trim((string)($d['service_number']??''))?:self::number();$base['status']=$d['service_status']??'in';$base['remaining']=$invoice;$base['created_at']=$now;$sql='INSERT INTO services (id,service_number,customer_name,customer_whatsapp,customer_address,device_name,service_name,color,accessories,service_price,parts_cost,delivery_cost,total_cost,profit,warranty_value,warranty_unit,service_status,payment_status,total_paid,remaining_payment,received_at,created_at,updated_at) VALUES (:id,:number,:customer_name,:customer_whatsapp,:customer_address,:device_name,:service_name,:color,:accessories,:service_price,:parts_cost,:delivery_cost,:total_cost,:profit,:warranty_value,:warranty_unit,:status,\'unpaid\',0,:remaining,:received_at,:created_at,:now)';}
        $pdo->prepare($sql)->execute($base);
    }

    private static function payment(PDO $pdo,string $id,array $d): void
    {
        $s=self::lock($pdo,$id);$amount=(float)($d['amount']??0);$method=(string)($d['payment_method']??'');$type=(string)($d['payment_type']??'down_payment');
        $invoice=(float)$s['service_price']+(float)$s['delivery_cost'];
        if($amount<=0)throw new DomainException('Nominal pembayaran harus lebih dari nol.');if(!in_array($method,self::METHODS,true))throw new DomainException('Metode pembayaran tidak valid.');if(!in_array($type,['full','down_payment','settlement'],true))throw new DomainException('Jenis pembayaran tidak valid.');if((float)$s['total_paid']+$amount>$invoice)throw new DomainException('Pembayaran melebihi sisa tagihan.');
        $paymentId=isset($d['id'])&&Uuid::valid((string)$d['id'])?(string)$d['id']:Uuid::v4();
        $existing=$pdo->prepare('SELECT service_id FROM service_payments WHERE id=:id AND deleted_at IS NULL LIMIT 1');$existing->execute(['id'=>$paymentId]);$existingService=$existing->fetchColumn();
        if($existingService!==false){if($existingService!==$id)throw new DomainException('ID pembayaran sudah digunakan.');self::totals($pdo,$id);return;}
        $now=self::date($d['paid_at']??null);$pdo->prepare('INSERT INTO service_payments (id,service_id,payment_type,payment_method,amount,paid_at,notes,created_at,updated_at) VALUES (:id,:sid,:type,:method,:amount,:paid_at,:notes,:created_at,:updated_at)')->execute(['id'=>$paymentId,'sid'=>$id,'type'=>$type,'method'=>$method,'amount'=>$amount,'paid_at'=>$now,'notes'=>self::null($d['notes']??null),'created_at'=>$now,'updated_at'=>$now]);
        self::totals($pdo,$id);
    }

    private static function totals(PDO $pdo,string $id): void
    {
        $s=self::lock($pdo,$id);$q=$pdo->prepare('SELECT COALESCE(SUM(amount),0) FROM service_payments WHERE service_id=:id AND deleted_at IS NULL');$q->execute(['id'=>$id]);$paid=(float)$q->fetchColumn();$invoice=(float)$s['service_price']+(float)$s['delivery_cost'];$left=max(0,$invoice-$paid);$status=$paid<=0?'unpaid':($left<=0?'paid':'down_payment');
        $pdo->prepare('UPDATE services SET total_paid=:paid,remaining_payment=:left,payment_status=:status,updated_at=:now WHERE id=:id')->execute(['paid'=>$paid,'left'=>$left,'status'=>$status,'now'=>gmdate('Y-m-d H:i:s'),'id'=>$id]);
    }

    private static function preset(PDO $pdo,string $id): void
    {
        $s=self::lock($pdo,$id);$now=gmdate('Y-m-d H:i:s');$pdo->prepare('INSERT INTO service_presets (id,device_name,service_name,service_price,parts_cost,is_active,created_at,updated_at) VALUES (:id,:device,:service,:price,:parts,1,:created_at,:updated_at) ON DUPLICATE KEY UPDATE service_price=VALUES(service_price),parts_cost=VALUES(parts_cost),is_active=1,updated_at=VALUES(updated_at),deleted_at=NULL')->execute(['id'=>Uuid::v4(),'device'=>$s['device_name'],'service'=>$s['service_name'],'price'=>$s['service_price'],'parts'=>$s['parts_cost'],'created_at'=>$now,'updated_at'=>$now]);
    }

    private static function warranty(array $d,?string $start): array
    {
        if($start===null||!isset($d['warranty_value'])||$d['warranty_value']===''||$d['warranty_value']===null)return[];$v=(int)$d['warranty_value'];$u=(string)($d['warranty_unit']??'');if($v<=0||!in_array($u,['hour','day'],true))throw new DomainException('Data garansi tidak valid.');$startDate=DateTimeImmutable::createFromFormat('!Y-m-d H:i:s',$start,new DateTimeZone('UTC'));if(!$startDate)throw new DomainException('Waktu mulai garansi tidak valid.');$end=$startDate->modify('+'.$v.' '.$u)->format('Y-m-d H:i:s');return['value'=>$v,'unit'=>$u,'start'=>$start,'end'=>$end];
    }

    private static function history(PDO $pdo,string $id,?string $old,string $new,string $at): void
    {$pdo->prepare('INSERT INTO service_status_history (id,service_id,previous_status,new_status,changed_at,created_at) VALUES (:id,:sid,:old,:new,:changed_at,:created_at)')->execute(['id'=>Uuid::v4(),'sid'=>$id,'old'=>$old,'new'=>$new,'changed_at'=>$at,'created_at'=>$at]);}

    private static function detail(string $id): array
    {$s=self::find($id);$pdo=Database::connection();$p=$pdo->prepare('SELECT * FROM service_payments WHERE service_id=:id AND deleted_at IS NULL ORDER BY paid_at');$p->execute(['id'=>$id]);$h=$pdo->prepare('SELECT * FROM service_status_history WHERE service_id=:id ORDER BY changed_at');$h->execute(['id'=>$id]);return['service'=>$s,'payments'=>$p->fetchAll(),'status_history'=>$h->fetchAll()];}

    private static function find(string $id): array
    {if(!Uuid::valid($id))Response::error('ID servis tidak valid.',422);$s=Database::connection()->prepare('SELECT * FROM services WHERE id=:id AND deleted_at IS NULL LIMIT 1');$s->execute(['id'=>$id]);$r=$s->fetch();if(!$r)Response::error('Data servis tidak ditemukan.',404);return$r;}

    private static function exists(PDO $pdo,string $id): bool
    {$s=$pdo->prepare('SELECT 1 FROM services WHERE id=:id AND deleted_at IS NULL LIMIT 1');$s->execute(['id'=>$id]);return(bool)$s->fetchColumn();}

    private static function lock(PDO $pdo,string $id): array
    {if(!Uuid::valid($id))throw new DomainException('ID servis tidak valid.');$s=$pdo->prepare('SELECT * FROM services WHERE id=:id AND deleted_at IS NULL LIMIT 1 FOR UPDATE');$s->execute(['id'=>$id]);$r=$s->fetch();if(!$r)throw new DomainException('Data servis tidak ditemukan.');return$r;}

    private static function validate(array $d): void
    {$e=[];if(trim((string)($d['device_name']??''))==='')$e['device_name']='Merk dan model wajib diisi.';if(trim((string)($d['service_name']??''))==='')$e['service_name']='Jenis servis wajib diisi.';if(!isset($d['service_price'])||!is_numeric($d['service_price'])||(float)$d['service_price']<0)$e['service_price']='Biaya servis wajib berupa angka.';foreach(['parts_cost'=>'Biaya sparepart','delivery_cost'=>'Ongkir']as$f=>$l)if(isset($d[$f])&&(!is_numeric($d[$f])||(float)$d[$f]<0))$e[$f]=$l.' tidak valid.';if(isset($d['service_status'])&&!in_array($d['service_status'],self::STATUSES,true))$e['service_status']='Status tidak valid.';if(isset($d['initial_payment'])&&(float)$d['initial_payment']>0&&!in_array((string)($d['payment_method']??''),self::METHODS,true))$e['payment_method']='Metode pembayaran wajib diisi.';if(isset($d['warranty_value'])&&$d['warranty_value']!==''&&$d['warranty_value']!==null&&(!is_numeric($d['warranty_value'])||(int)$d['warranty_value']<=0||!in_array((string)($d['warranty_unit']??''),['hour','day'],true)))$e['warranty']='Data garansi tidak valid.';if($e!==[])Response::error('Data servis belum valid.',422,$e);}

    private static function number(): string{return'SV-'.gmdate('Ymd-His').'-'.strtoupper(substr(str_replace('-','',Uuid::v4()),0,5));}
    private static function null(mixed $v): ?string{$v=trim((string)($v??''));return$v===''?null:$v;}
    private static function date(mixed $v): string{if(!is_string($v)||trim($v)==='')return gmdate('Y-m-d H:i:s');$d=new DateTimeImmutable($v,new DateTimeZone('UTC'));return$d->setTimezone(new DateTimeZone('UTC'))->format('Y-m-d H:i:s');}
    private static function fail(Throwable $e): never{if($e instanceof DomainException)Response::error($e->getMessage(),422);if($e instanceof PDOException&&(string)$e->getCode()==='23000')Response::error('Nomor servis atau ID sudah digunakan.',409);throw$e;}
}
