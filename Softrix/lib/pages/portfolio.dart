import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class PortfolioPage extends StatefulWidget {
  final double virtualMoney;
  final Map<String, List<FlSpot>> priceData;
  final Map<String, Map<String, double>> investments;
  final String selectedTimePeriod;
  final Function(double) onMoneyUpdate;
  final Function(Map<String, Map<String, double>>) onInvestmentsUpdate;
  final Function() onFetchPriceData;

  const PortfolioPage({
    super.key,
    required this.virtualMoney,
    required this.priceData,
    required this.investments,
    required this.selectedTimePeriod,
    required this.onMoneyUpdate,
    required this.onInvestmentsUpdate,
    required this.onFetchPriceData,
  });

  @override
  _PortfolioPageState createState() => _PortfolioPageState();
}

class _PortfolioPageState extends State<PortfolioPage> {
  static const double _defaultExchangeRate = 4.3;
  double usdToMyrRate = _defaultExchangeRate;
  bool _isLoading = true;
  bool _isTransactionInProgress = false;
  String? _errorMessage;
  late final SupabaseClient supabase;
  final currencyFormat = NumberFormat.currency(locale: 'en_MY', symbol: 'RM ', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    supabase = Supabase.instance.client;
    if (supabase.auth.currentUser == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, '/login');
      });
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeData());
  }

  Future<void> _initializeData() async {
    setState(() => _isLoading = true);
    try {
      await Future.wait<void>([
        fetchExchangeRate(),
        widget.onFetchPriceData(),
        _loadInitialData(),
      ]);
    } catch (e) {
      setState(() => _errorMessage = 'Initialization failed: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadInitialData() async {
    if (supabase.auth.currentUser == null) {
      setState(() => _errorMessage = 'User not authenticated');
      return;
    }

    try {
      final profileResponse = await supabase
          .from('profiles')
          .select('virtual_money')
          .eq('id', supabase.auth.currentUser!.id)
          .single();

      final double dbVirtualMoney = (profileResponse['virtual_money'] as num?)?.toDouble() ?? widget.virtualMoney;
      widget.onMoneyUpdate(dbVirtualMoney);

      await _reloadInvestments();
    } catch (e) {
      setState(() => _errorMessage = 'Failed to load initial data: $e');
    }
  }

  Future<void> _reloadInvestments() async {
    try {
      final transactionsResponse = await supabase
          .from('stock_transactions')
          .select()
          .eq('user_id', supabase.auth.currentUser!.id);
      final transactions = transactionsResponse as List<dynamic>;
      final reconstructedInvestments = _reconstructInvestments(transactions);
      widget.onInvestmentsUpdate(reconstructedInvestments);
    } catch (e) {
      setState(() => _errorMessage = 'Failed to reload investments: $e');
    }
  }

  Map<String, Map<String, double>> _reconstructInvestments(List<dynamic> transactions) {
    final reconstructedInvestments = {
      'Bitcoin': {'quantity': 0.0, 'purchasePrice': 0.0},
      'Gold': {'quantity': 0.0, 'purchasePrice': 0.0},
      'Tesla': {'quantity': 0.0, 'purchasePrice': 0.0},
      'Apple': {'quantity': 0.0, 'purchasePrice': 0.0},
      'Maybank': {'quantity': 0.0, 'purchasePrice': 0.0},
    };

    for (var tx in transactions) {
      final asset = tx['asset'] as String;
      final quantity = (tx['quantity'] as num).toDouble();
      final pricePerUnit = (tx['price_per_unit'] as num).toDouble();
      final type = tx['transaction_type'] as String;

      if (!reconstructedInvestments.containsKey(asset)) continue;

      if (type == 'BUY') {
        final currentQuantity = reconstructedInvestments[asset]!['quantity'] ?? 0.0;
        final currentPurchasePrice = reconstructedInvestments[asset]!['purchasePrice'] ?? 0.0;
        final newQuantity = currentQuantity + quantity;
        final newPurchasePrice = currentQuantity == 0
            ? pricePerUnit
            : ((currentPurchasePrice * currentQuantity) + (pricePerUnit * quantity)) / newQuantity;
        reconstructedInvestments[asset]!['quantity'] = newQuantity;
        reconstructedInvestments[asset]!['purchasePrice'] = newPurchasePrice;
      } else if (type == 'SELL') {
        reconstructedInvestments[asset]!['quantity'] = (reconstructedInvestments[asset]!['quantity'] ?? 0.0) - quantity;
        if (reconstructedInvestments[asset]!['quantity'] == 0.0) {
          reconstructedInvestments[asset]!['purchasePrice'] = 0.0;
        }
      }
    }

    return reconstructedInvestments;
  }

  Future<void> fetchExchangeRate() async {
    try {
      final response = await http.get(Uri.parse('https://api.exchangerate-api.com/v4/latest/USD'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() => usdToMyrRate = (data['rates']['MYR'] as num).toDouble());
      } else {
        throw Exception('Failed to fetch exchange rate: ${response.statusCode}');
      }
    } catch (e) {
      setState(() => usdToMyrRate = _defaultExchangeRate);
    }
  }

  double getCurrentPrice(String asset) {
    final data = widget.priceData[asset];
    if (data == null || data.isEmpty) {
      return 0.0;
    }
    final priceInMyr = data.last.y;
    return priceInMyr;
  }

  double calculateProfitLoss(String asset) {
    final quantity = widget.investments[asset]!['quantity'] ?? 0.0;
    final purchasePrice = widget.investments[asset]!['purchasePrice'] ?? 0.0;
    final currentPrice = getCurrentPrice(asset);
    if (quantity == 0.0 || currentPrice == 0.0) return 0.0;
    return (currentPrice - purchasePrice) * quantity;
  }

  double calculateTotalPortfolioValue() {
    double total = 0.0;
    for (var asset in widget.investments.keys) {
      final quantity = widget.investments[asset]!['quantity'] ?? 0.0;
      final currentPrice = getCurrentPrice(asset);
      total += quantity * currentPrice;
    }
    return total;
  }

  double calculateTotalProfitLoss() {
    double total = 0.0;
    for (var asset in widget.investments.keys) {
      total += calculateProfitLoss(asset);
    }
    return total;
  }

  Future<void> investInAsset(String asset, double amount) async {
    if (_isTransactionInProgress) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Another transaction is in progress. Please wait.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (supabase.auth.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User not authenticated'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final currentPrice = getCurrentPrice(asset);
    if (currentPrice <= 0.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot invest: No valid price data available'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (amount > widget.virtualMoney) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Insufficient virtual money'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _isTransactionInProgress = true;
    });
    try {
      final quantity = amount / currentPrice;
      await supabase.rpc('perform_transaction', params: {
        'p_user_id': supabase.auth.currentUser!.id,
        'p_asset': asset,
        'p_transaction_type': 'BUY',
        'p_quantity': quantity,
        'p_price_per_unit': currentPrice,
        'p_total_amount': amount,
        'p_new_virtual_money': widget.virtualMoney - amount,
      });

      await _reloadInvestments();

      setState(() {
        widget.onMoneyUpdate(widget.virtualMoney - amount);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully invested ${currencyFormat.format(amount)} in $asset'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Investment failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
        _isTransactionInProgress = false;
      });
    }
  }

  Future<void> sellAsset(String asset, double quantityToSell) async {
    if (_isTransactionInProgress) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Another transaction is in progress. Please wait.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (supabase.auth.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User not authenticated'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final currentPrice = getCurrentPrice(asset);
    if (currentPrice <= 0.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot sell: No valid price data available'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final currentQuantity = widget.investments[asset]!['quantity'] ?? 0.0;
    const double epsilon = 1e-8;
    if (quantityToSell > currentQuantity + epsilon) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Insufficient quantity to sell'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _isTransactionInProgress = true;
    });
    try {
      final amount = quantityToSell * currentPrice;
      await supabase.rpc('perform_transaction', params: {
        'p_user_id': supabase.auth.currentUser!.id,
        'p_asset': asset,
        'p_transaction_type': 'SELL',
        'p_quantity': quantityToSell,
        'p_price_per_unit': currentPrice,
        'p_total_amount': amount,
        'p_new_virtual_money': widget.virtualMoney + amount,
      });

      await _reloadInvestments();

      setState(() {
        widget.onMoneyUpdate(widget.virtualMoney + amount);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully sold $quantityToSell units of $asset for ${currencyFormat.format(amount)}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sell operation failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
        _isTransactionInProgress = false;
      });
    }
  }

  Future<void> _showInvestDialog(String asset) async {
    TextEditingController amountController = TextEditingController();
    final currentPrice = getCurrentPrice(asset);

    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Invest in $asset'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF007BFF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Color(0xFF007BFF), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Current Price: ${currencyFormat.format(currentPrice)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF007BFF),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Available: ${currencyFormat.format(widget.virtualMoney)}',
                            style: const TextStyle(color: Color(0xFF007BFF)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: false),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: InputDecoration(
                  labelText: 'Amount (RM)',
                  prefixText: 'RM ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF007BFF), width: 2),
                  ),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 8),
              StatefulBuilder(
                builder: (context, setState) {
                  double amount = double.tryParse(amountController.text) ?? 0;
                  double estimatedQuantity = currentPrice > 0 ? amount / currentPrice : 0;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Estimated quantity: ${estimatedQuantity.toStringAsFixed(8)} units',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildQuickAmountButton('25%', widget.virtualMoney * 0.25, amountController, setState),
                          _buildQuickAmountButton('50%', widget.virtualMoney * 0.5, amountController, setState),
                          _buildQuickAmountButton('75%', widget.virtualMoney * 0.75, amountController, setState),
                          _buildQuickAmountButton('Max', widget.virtualMoney, amountController, setState),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final amount = double.tryParse(amountController.text);
                if (amount == null || amount <= 0 || amount.isNaN || amount.isInfinite) {
                  _showErrorDialog(context, 'Please enter a valid amount greater than 0.');
                  return;
                }
                if (amount > widget.virtualMoney) {
                  _showErrorDialog(context, 'Insufficient virtual money.');
                  return;
                }
                Navigator.pop(context);
                investInAsset(asset, amount);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF007BFF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Invest'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildQuickAmountButton(String label, double amount, TextEditingController controller, Function setState) {
    return InkWell(
      onTap: () {
        controller.text = amount.toStringAsFixed(2);
        setState(() {});
      },
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFF007BFF)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF007BFF),
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Future<void> _showSellDialog(String asset) async {
    TextEditingController quantityController = TextEditingController();
    final currentQuantity = widget.investments[asset]!['quantity'] ?? 0.0;
    final currentPrice = getCurrentPrice(asset);

    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Sell $asset'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF007BFF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Color(0xFF007BFF), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Current Price: ${currencyFormat.format(currentPrice)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF007BFF),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Available: ${currentQuantity.toStringAsFixed(8)} units',
                            style: const TextStyle(color: Color(0xFF007BFF)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: quantityController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: false),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: InputDecoration(
                  labelText: 'Quantity to Sell',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF007BFF), width: 2),
                  ),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 8),
              StatefulBuilder(
                builder: (context, setState) {
                  double quantity = double.tryParse(quantityController.text) ?? 0;
                  double estimatedValue = quantity * currentPrice;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Estimated value: ${currencyFormat.format(estimatedValue)}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildQuickQuantityButton('25%', currentQuantity * 0.25, quantityController, setState),
                          _buildQuickQuantityButton('50%', currentQuantity * 0.5, quantityController, setState),
                          _buildQuickQuantityButton('75%', currentQuantity * 0.75, quantityController, setState),
                          _buildQuickQuantityButton('Max', currentQuantity, quantityController, setState),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final quantity = double.tryParse(quantityController.text);
                if (quantity == null || quantity <= 0 || quantity.isNaN || quantity.isInfinite) {
                  _showErrorDialog(context, 'Please enter a valid quantity greater than 0.');
                  return;
                }
                const double epsilon = 1e-8;
                if (quantity > currentQuantity + epsilon) {
                  _showErrorDialog(context, 'Quantity to sell cannot exceed available quantity (${currentQuantity.toStringAsFixed(8)}).');
                  return;
                }
                Navigator.pop(context);
                sellAsset(asset, quantity);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF007BFF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Sell'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildQuickQuantityButton(String label, double quantity, TextEditingController controller, Function setState) {
    return InkWell(
      onTap: () {
        controller.text = quantity.toStringAsFixed(8);
        setState(() {});
      },
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFF007BFF)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF007BFF),
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 8),
            const Text('Error'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalPortfolioValue = calculateTotalPortfolioValue();
    final totalProfitLoss = calculateTotalProfitLoss();

    return Scaffold(
      backgroundColor: Colors.white,
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF007BFF)),
        ),
      )
          : RefreshIndicator(
        color: const Color(0xFF007BFF),
        onRefresh: _initializeData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPortfolioHeader(totalPortfolioValue, totalProfitLoss),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Your Investments',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2D3436),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh, color: Color(0xFF007BFF)),
                          onPressed: _initializeData,
                          tooltip: 'Refresh data',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_errorMessage != null)
                      _buildErrorMessage()
                    else if (_hasNoInvestments())
                      _buildEmptyState()
                    else
                      Column(
                        children: ['Bitcoin', 'Gold', 'Tesla', 'Apple', 'Maybank']
                            .map((asset) => _buildAssetCard(asset))
                            .toList(),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _hasNoInvestments() {
    for (var asset in widget.investments.keys) {
      if ((widget.investments[asset]!['quantity'] ?? 0.0) > 0) {
        return false;
      }
    }
    return true;
  }

  Widget _buildPortfolioHeader(double totalValue, double totalProfitLoss) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 30, 16, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF007BFF), Color(0xFF4DA3FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Portfolio Value',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    currencyFormat.format(totalValue),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        totalProfitLoss >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                        color: totalProfitLoss >= 0 ? Colors.green[100] : Colors.red[100],
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${totalProfitLoss >= 0 ? '+' : ''}${currencyFormat.format(totalProfitLoss)}',
                        style: TextStyle(
                          color: totalProfitLoss >= 0 ? Colors.green[100] : Colors.red[100],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Available Cash',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currencyFormat.format(widget.virtualMoney),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildPortfolioStat(
                  'Assets',
                  _countActiveAssets().toString(),
                  Icons.pie_chart,
                ),
              ),
              Expanded(
                child: _buildPortfolioStat(
                  'Return',
                  totalValue > 0 ? '${((totalProfitLoss / (totalValue - totalProfitLoss)) * 100).toStringAsFixed(2)}%' : '0.00%',
                  Icons.show_chart,
                ),
              ),
              Expanded(
                child: _buildPortfolioStat(
                  'Last Update',
                  DateFormat('HH:mm').format(DateTime.now()),
                  Icons.access_time,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  int _countActiveAssets() {
    int count = 0;
    for (var asset in widget.investments.keys) {
      if ((widget.investments[asset]!['quantity'] ?? 0.0) > 0) {
        count++;
      }
    }
    return count;
  }

  Widget _buildPortfolioStat(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline,
            color: Colors.red,
            size: 24,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Error Loading Data',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No Investments Yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start investing in assets to build your portfolio',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showInvestDialog('Bitcoin'),
            icon: const Icon(Icons.add),
            label: const Text('Make Your First Investment'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF007BFF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssetCard(String asset) {
    final currentPrice = getCurrentPrice(asset);
    final profitLoss = calculateProfitLoss(asset);
    final quantity = widget.investments[asset]!['quantity'] ?? 0.0;
    final purchasePrice = widget.investments[asset]!['purchasePrice'] ?? 0.0;

    if (quantity <= 0) return const SizedBox.shrink();

    final percentChange = purchasePrice > 0
        ? ((currentPrice - purchasePrice) / purchasePrice) * 100
        : 0.0;

    IconData assetIcon;
    switch (asset) {
      case 'Bitcoin':
        assetIcon = Icons.currency_bitcoin;
        break;
      case 'Gold':
        assetIcon = Icons.monetization_on;
        break;
      case 'Tesla':
        assetIcon = Icons.electric_car;
        break;
      case 'Apple':
        assetIcon = Icons.apple;
        break;
      case 'Maybank':
        assetIcon = Icons.account_balance;
        break;
      default:
        assetIcon = Icons.business;
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF007BFF).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    assetIcon,
                    color: const Color(0xFF007BFF),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        asset,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D3436),
                        ),
                      ),
                      Text(
                        'Quantity: ${quantity.toStringAsFixed(8)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      currencyFormat.format(currentPrice),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3436),
                      ),
                    ),
                    Row(
                      children: [
                        Icon(
                          percentChange >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                          color: percentChange >= 0 ? Colors.green : Colors.red,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${percentChange.toStringAsFixed(2)}%',
                          style: TextStyle(
                            fontSize: 14,
                            color: percentChange >= 0 ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Purchase Price',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        currencyFormat.format(purchasePrice),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D3436),
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Current Value',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        currencyFormat.format(quantity * currentPrice),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D3436),
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Profit/Loss',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        currencyFormat.format(profitLoss),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: profitLoss >= 0 ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isTransactionInProgress ? null : () => _showInvestDialog(asset),
                    icon: const Icon(Icons.add),
                    label: const Text('Buy More'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF007BFF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: (_isTransactionInProgress || quantity <= 0) ? null : () => _showSellDialog(asset),
                    icon: const Icon(Icons.sell),
                    label: const Text('Sell'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF007BFF),
                      side: const BorderSide(color: Color(0xFF007BFF)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

