class Sale {
  int? id;
  int customerId;
  int productId;
  String notes;
  String saleDate;
  int? colleagueId;
  double? commissionRate;
  String? policyNumber;
  String? policyStatus;
  String? paymentMethod;
  int? paymentTerm;
  int? guaranteePeriod;
  String? renewalDate;

  Sale({
    this.id,
    required this.customerId,
    required this.productId,
    required this.notes,
    required this.saleDate,
    this.colleagueId,
    this.commissionRate,
    this.policyNumber,
    this.policyStatus = '有效',
    this.paymentMethod,
    this.paymentTerm,
    this.guaranteePeriod,
    this.renewalDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customer_id': customerId,
      'product_id': productId,
      'notes': notes,
      'sale_date': saleDate,
      'colleague_id': colleagueId,
      'commission_rate': commissionRate,
      'policy_number': policyNumber,
      'policy_status': policyStatus,
      'payment_method': paymentMethod,
      'payment_term': paymentTerm,
      'guarantee_period': guaranteePeriod,
      'renewal_date': renewalDate,
    };
  }

  factory Sale.fromMap(Map<String, dynamic> map) {
    return Sale(
      id: map['id'],
      customerId: map['customer_id'],
      productId: map['product_id'],
      notes: map['notes'] ?? '',
      saleDate: map['sale_date'],
      colleagueId: map['colleague_id'],
      commissionRate: map['commission_rate'],
      policyNumber: map['policy_number'],
      policyStatus: map['policy_status'] ?? '有效',
      paymentMethod: map['payment_method'],
      paymentTerm: map['payment_term'],
      guaranteePeriod: map['guarantee_period'],
      renewalDate: map['renewal_date'],
    );
  }
}
