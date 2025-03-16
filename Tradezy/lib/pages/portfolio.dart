import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';

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

  Future<void> investInAsset(String asset, double amount) async {
    if (_isTransactionInProgress) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Another transaction is in progress. Please wait.')),
      );
      return;
    }

    if (supabase.auth.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not authenticated')),
      );
      return;
    }

    final currentPrice = getCurrentPrice(asset);
    if (currentPrice <= 0.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot invest: No valid price data available')),
      );
      return;
    }

    if (amount > widget.virtualMoney) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Insufficient virtual money')),
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
        SnackBar(content: Text('Invested RM ${amount.toStringAsFixed(2)} in $asset')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Investment failed: $e')),
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
        const SnackBar(content: Text('Another transaction is in progress. Please wait.')),
      );
      return;
    }

    if (supabase.auth.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not authenticated')),
      );
      return;
    }

    final currentPrice = getCurrentPrice(asset);
    if (currentPrice <= 0.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot sell: No valid price data available')),
      );
      return;
    }

    final currentQuantity = widget.investments[asset]!['quantity'] ?? 0.0;
    const double epsilon = 1e-8;
    if (quantityToSell > currentQuantity + epsilon) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Insufficient quantity to sell')),
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
        SnackBar(content: Text('Sold $quantityToSell units of $asset for RM ${amount.toStringAsFixed(2)}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sell operation failed: $e')),
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
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Text('Invest in $asset', style: const TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Current Price: RM ${getCurrentPrice(asset).toStringAsFixed(2)}', style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 10),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: false),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Amount (RM)',
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white)),
            ),
            TextButton(
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
              child: const Text('Invest', style: TextStyle(color: Colors.blueAccent)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showSellDialog(String asset) async {
    TextEditingController quantityController = TextEditingController();
    final currentQuantity = widget.investments[asset]!['quantity'] ?? 0.0;
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Text('Sell $asset', style: const TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Current Price: RM ${getCurrentPrice(asset).toStringAsFixed(2)}', style: const TextStyle(color: Colors.white70)),
              Text('Available Quantity: ${currentQuantity.toStringAsFixed(8)}', style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 10),
              TextField(
                controller: quantityController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: false),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Quantity to Sell',
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white)),
            ),
            TextButton(
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
              child: const Text('Sell', style: TextStyle(color: Colors.blueAccent)),
            ),
            TextButton(
              onPressed: () {
                quantityController.text = currentQuantity.toStringAsFixed(8);
              },
              child: const Text('Sell All', style: TextStyle(color: Colors.blueAccent)),
            ),
          ],
        );
      },
    );
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Error', style: TextStyle(color: Colors.white)),
        content: Text(message, style: const TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: Colors.blueAccent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Portfolio', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
      ),
      backgroundColor: Colors.black,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Virtual Money: RM ${widget.virtualMoney.toStringAsFixed(2)}',
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Your Investments',
                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    if (_errorMessage != null)
                      Center(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red, fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      Column(
                        children: ['Bitcoin', 'Gold', 'Tesla', 'Apple', 'Maybank'].map((asset) {
                          final currentPrice = getCurrentPrice(asset);
                          final profitLoss = calculateProfitLoss(asset);
                          final quantity = widget.investments[asset]!['quantity'] ?? 0.0;
                          return Card(
                            color: Colors.grey[900],
                            margin: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    asset,
                                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Current Price: RM ${currentPrice.toStringAsFixed(2)}',
                                    style: const TextStyle(color: Colors.white, fontSize: 16),
                                  ),
                                  Text(
                                    'Quantity Owned: ${quantity.toStringAsFixed(8)}',
                                    style: const TextStyle(color: Colors.white, fontSize: 16),
                                  ),
                                  Text(
                                    'Profit/Loss: RM ${profitLoss.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      color: profitLoss >= 0 ? Colors.green : Colors.red,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    children: [
                                      ElevatedButton(
                                        onPressed: _isTransactionInProgress ? null : () => _showInvestDialog(asset),
                                        child: const Text('Invest'),
                                      ),
                                      ElevatedButton(
                                        onPressed: (_isTransactionInProgress || quantity <= 0) ? null : () => _showSellDialog(asset),
                                        child: const Text('Sell'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}