class Sale {
  int? id;
  int customerId;
  int productId;
  double? amount; // 销售金额 (Sale amount / premium)
  String notes; // 销售备注
  String saleDate;
  int? colleagueId;
  double? commissionRate; // 佣金比例 (Commission rate as percentage, e.g. 5.0 = 5%)
  String? policyNumber; // 保单号
  String? policyStatus; // 保单状态 (Policy status, e.g. "有效"/"已失效")
  String? paymentMethod; // 缴费方式 (Payment method, e.g. "年缴"/"趸交")
  int? paymentTermMonths; // 缴费期限月数 (Payment term in months)
  int? guaranteePeriodYears; // 保障期限年数 (Guarantee/Coverage period in years)
  String? renewalDate; // 续期日期

  Sale({
    this.id,
    required this.customerId,
    required this.productId,
    this.amount,
    required this.notes,
    required this.saleDate,
    this.colleagueId,
    this.commissionRate,
    this.policyNumber,
    this.policyStatus = '有效',
    this.paymentMethod,
    this.paymentTermMonths,
    this.guaranteePeriodYears,
    this.renewalDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customer_id': customerId,
      'product_id': productId,
      'amount': amount,
      'notes': notes,
      'sale_date': saleDate,
      'colleague_id': colleagueId,
      'commission_rate': commissionRate,
      'policy_number': policyNumber,
      'policy_status': policyStatus,
      'payment_method': paymentMethod,
      'payment_term': paymentTermMonths,
      'guarantee_period': guaranteePeriodYears,
      'renewal_date': renewalDate,
    };
  }

  factory Sale.fromMap(Map<String, dynamic> map) {
    return Sale(
      id: (map['id'] as num?)?.toInt(),
      customerId: (map['customer_id'] as num?)?.toInt() ?? 0,
      productId: (map['product_id'] as num?)?.toInt() ?? 0,
      amount: (map['amount'] as num?)?.toDouble(),
      notes: map['notes'] as String? ?? '',
      saleDate: map['sale_date'] as String? ?? '',
      colleagueId: (map['colleague_id'] as num?)?.toInt(),
      commissionRate: (map['commission_rate'] as num?)?.toDouble(),
      policyNumber: map['policy_number'] as String?,
      policyStatus: map['policy_status'] as String? ?? '有效',
      paymentMethod: map['payment_method'] as String?,
      paymentTermMonths: (map['payment_term'] as num?)?.toInt(),
      guaranteePeriodYears: (map['guarantee_period'] as num?)?.toInt(),
      renewalDate: map['renewal_date'] as String?,
    );
  }
}
