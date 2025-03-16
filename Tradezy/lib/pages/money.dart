import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart'; // For graphs
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';


class FinanceApp extends StatefulWidget {
  @override
  _FinanceAppState createState() => _FinanceAppState();
}

class _FinanceAppState extends State<FinanceApp> {
  int _selectedIndex = 0;
  final List<Widget> _screens = [HomeScreen(), AddTransactionScreen(), StatsScreen(), SavingsScreen()];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(), // Dark mode
      home: Scaffold(
        body: _screens[_selectedIndex],
        bottomNavigationBar: BottomNavigationBar(
          backgroundColor: Colors.black,
          selectedItemColor: Colors.blueAccent,
          unselectedItemColor: Colors.grey,
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          items: [
            BottomNavigationBarItem(icon: Icon(Icons.account_balance), label: 'Bank'),
            BottomNavigationBarItem(icon: Icon(Icons.add), label: 'Add'),
            BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Stats'),
            BottomNavigationBarItem(icon: Icon(Icons.trending_up), label: 'Invest'),
          ],
        ),
      ),
    );
  }
}


class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _transactions = [];
  List<Map<String, dynamic>> _filteredTransactions = [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _selectedCategory = 'All';

  final List<String> _categories = [
    'All',
    'Food and Drink',
    'Income',
    'Shopping',
    'Transportation',
    'Entertainment',
    'Investment',
    'Housing',
    'Tuition Fee',
  ];

  @override
  void initState() {
    super.initState();
    _fetchTransactions();
  }

  Future<void> _fetchTransactions() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        throw Exception('You must be logged in to view transactions.');
      }

      final response = await supabase
          .from('transactions')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      setState(() {
        _transactions = response as List<Map<String, dynamic>>;
        _filterTransactions();
        _isLoading = false;
      });
    } catch (error) {
      setState(() {
        _errorMessage = 'Failed to fetch transactions: $error';
        _isLoading = false;
      });
    }
  }

  void _filterTransactions() {
    setState(() {
      if (_selectedCategory == 'All') {
        _filteredTransactions = _transactions;
      } else {
        _filteredTransactions = _transactions
            .where((transaction) => transaction['purpose'] == _selectedCategory)
            .toList();
      }
    });
  }

  Map<String, double> _calculateTotals() {
    double totalIncome = 0.0;
    double totalExpense = 0.0;

    for (var transaction in _filteredTransactions) {
      if (transaction['type'] == 'Income') {
        totalIncome += transaction['amount'] as double;
      } else if (transaction['type'] == 'Expense') {
        totalExpense += transaction['amount'] as double;
      }
    }

    return {
      'income': totalIncome,
      'expense': totalExpense,
      'net': totalIncome - totalExpense,
    };
  }

  @override
  Widget build(BuildContext context) {
    final totals = _calculateTotals();
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('My Finance', style: TextStyle(color: Colors.white)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(fontSize: 18, color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : Column(
                  children: [
                    // Category filter dropdown
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        items: _categories.map((String category) {
                          return DropdownMenuItem<String>(
                            value: category,
                            child: Text(category),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedCategory = value;
                            _filterTransactions();
                          });
                        },
                        decoration: const InputDecoration(
                          labelText: 'Filter by Category',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    // Summary Card
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Card(
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Summary', style: Theme.of(context).textTheme.titleLarge),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Income:'),
                                  Text(
                                    'RM${totals['income']!.toStringAsFixed(2)}',
                                    style: const TextStyle(color: Colors.green),
                                  ),
                                ],
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Expense:'),
                                  Text(
                                    'RM${totals['expense']!.toStringAsFixed(2)}',
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                ],
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Net:'),
                                  Text(
                                    'RM${totals['net']!.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: totals['net']! >= 0 ? Colors.green : Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Transaction List
                    Expanded(
                      child: _filteredTransactions.isEmpty
                          ? const Center(
                              child: Text(
                                'No transactions for this category.',
                                style: TextStyle(fontSize: 18),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _filteredTransactions.length,
                              itemBuilder: (context, index) {
                                final transaction = _filteredTransactions[index];
                                return Card(
                                  margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                                  child: ListTile(
                                    title: Text('${transaction['type']} - RM${transaction['amount'].toStringAsFixed(2)}'),
                                    subtitle: Text('${transaction['purpose']} • ${transaction['created_at'].toString().substring(0, 10)}'),
                                    trailing: Icon(
                                      transaction['type'] == 'Income' ? Icons.arrow_upward : Icons.arrow_downward,
                                      color: transaction['type'] == 'Income' ? Colors.green : Colors.red,
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }
}

class AddTransactionScreen extends StatefulWidget {
  @override
  _AddTransactionScreenState createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  String _transactionType = 'Expense'; // Default type
  String _selectedPurpose = 'Food and Drink'; // Default purpose

  final List<String> _purposes = [
    'Food and Drink',
    'Shopping',
    'Income',
    'Transportation',
    'Entertainment',
    'Investment',
    'Housing',
    'Tuition Fee'
  ];

  // Supabase client (assuming it's initialized globally)
  final supabase = Supabase.instance.client;

  Future<void> _saveTransaction() async {
    if (!_formKey.currentState!.validate()) {
      return; // Stop if form validation fails
    }

    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        throw Exception('You must be logged in to add a transaction.');
      }

      // Insert transaction into Supabase
      await supabase.from('transactions').insert({
        'user_id': user.id,
        'type': _transactionType,
        'amount': double.parse(_amountController.text.trim()),
        'purpose': _selectedPurpose,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaction successfully added!')),
        );

      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add transaction: $error')),
        );
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Transaction'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => FinanceApp()));

          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              DropdownButtonFormField(
                value: _transactionType,
                items: ['Income', 'Expense'].map((String category) {
                  return DropdownMenuItem(value: category, child: Text(category));
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _transactionType = value as String;
                  });
                },
                decoration: const InputDecoration(labelText: 'Transaction Type'),
              ),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Amount'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter an amount';
                  }
                  if (double.tryParse(value) == null || double.parse(value) <= 0) {
                    return 'Please enter a valid positive amount';
                  }
                  return null;
                },
              ),
              DropdownButtonFormField(
                value: _selectedPurpose,
                items: _purposes.map((String purpose) {
                  return DropdownMenuItem(value: purpose, child: Text(purpose));
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedPurpose = value as String;
                  });
                },
                decoration: const InputDecoration(labelText: 'Purpose'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _saveTransaction,
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}



class StatsScreen extends StatefulWidget {
  @override
  _StatsScreenState createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final supabase = Supabase.instance.client;
  Map<String, double> _transactionsByPurpose = {};
  Map<String, double> _incomeByMonth = {};
  Map<String, double> _expenseByMonth = {};
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        throw Exception('You must be logged in to view statistics.');
      }

      final purposeResponse = await supabase
          .rpc('get_transactions_by_purpose', params: {'user_id_param': user.id});

      final incomeResponse = await supabase
          .rpc('get_income_by_month', params: {'user_id_param': user.id});

      final expenseResponse = await supabase
          .rpc('get_expense_by_month', params: {'user_id_param': user.id});

      setState(() {
        _transactionsByPurpose = {
          for (var item in purposeResponse as List<dynamic>)
            item['purpose']: (item['total_amount'] as num?)?.toDouble() ?? 0.0
        };
        _incomeByMonth = {
          for (var item in incomeResponse as List<dynamic>)
            item['month']: (item['total_income'] as num?)?.toDouble() ?? 0.0
        };
        _expenseByMonth = {
          for (var item in expenseResponse as List<dynamic>)
            item['month']: (item['total_expense'] as num?)?.toDouble() ?? 0.0
        };
        _isLoading = false;
      });
    } catch (error) {
      setState(() {
        _errorMessage = 'Failed to fetch stats: $error';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final allMonths = {..._incomeByMonth.keys, ..._expenseByMonth.keys}.toList()
      ..sort((a, b) => b.compareTo(a)); // Sort descending

    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistics'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => FinanceApp()));

          },
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!, style: const TextStyle(fontSize: 18, color: Colors.red)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Transactions by Purpose', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 250,
                        child: _transactionsByPurpose.isEmpty
                            ? const Center(child: Text('No transactions yet.', style: TextStyle(fontSize: 16)))
                            : PieChart(
                                PieChartData(
                                  sections: _transactionsByPurpose.entries.map((entry) {
                                    final index = _transactionsByPurpose.keys.toList().indexOf(entry.key);
                                    return PieChartSectionData(
                                      value: entry.value,
                                      title: '${entry.key}\nRM${entry.value.toStringAsFixed(0)}',
                                      color: Colors.primaries[index % Colors.primaries.length],
                                      radius: 80,
                                      titleStyle: const TextStyle(fontSize: 12, color: Colors.white),
                                    );
                                  }).toList(),
                                  sectionsSpace: 2,
                                  centerSpaceRadius: 40,
                                ),
                              ),
                      ),
                      const SizedBox(height: 32),
                      const Text('Income and Expenses by Month', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 300,
                        child: allMonths.isEmpty
                            ? const Center(child: Text('No income or expenses yet.', style: TextStyle(fontSize: 16)))
                            : BarChart(
                                BarChartData(
                                  alignment: BarChartAlignment.spaceAround,
                                  maxY: (allMonths.isNotEmpty)
                                      ? (_incomeByMonth.values.isNotEmpty || _expenseByMonth.values.isNotEmpty)
                                          ? (_incomeByMonth.values.isNotEmpty
                                                  ? _incomeByMonth.values.reduce((a, b) => a > b ? a : b)
                                                  : _expenseByMonth.values.reduce((a, b) => a > b ? a : b)) *
                                              1.2
                                          : 100
                                      : 100,
                                  barGroups: allMonths.map((month) {
                                    final index = allMonths.indexOf(month);
                                    return BarChartGroupData(
                                      x: index,
                                      barRods: [
                                        BarChartRodData(
                                          toY: _incomeByMonth[month] ?? 0,
                                          color: Colors.green,
                                          width: 12,
                                        ),
                                        BarChartRodData(
                                          toY: _expenseByMonth[month] ?? 0,
                                          color: Colors.red,
                                          width: 12,
                                        ),
                                      ],
                                      barsSpace: 4,
                                    );
                                  }).toList(),
                                  titlesData: FlTitlesData(
                                    bottomTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        getTitlesWidget: (value, meta) {
                                          final index = value.toInt();
                                          if (index >= 0 && index < allMonths.length) {
                                            return Text(
                                              allMonths[index],
                                              style: const TextStyle(fontSize: 12),
                                            );
                                          }
                                          return const Text('');
                                        },
                                        reservedSize: 40,
                                      ),
                                    ),
                                    leftTitles: AxisTitles(
                                      sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                                    ),
                                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  ),
                                  borderData: FlBorderData(show: false),
                                  gridData: FlGridData(show: false),
                                ),
                              ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(children: const [Icon(Icons.circle, color: Colors.green, size: 12), SizedBox(width: 4), Text('Income')]),
                          const SizedBox(width: 16),
                          Row(children: const [Icon(Icons.circle, color: Colors.red, size: 12), SizedBox(width: 4), Text('Expenses')]),
                        ],
                      ),
                    ],
                  ),
                ),
    );
  }
}


class SavingsScreen extends StatefulWidget {
  @override
  _SavingsScreenState createState() => _SavingsScreenState();
}

class _SavingsScreenState extends State<SavingsScreen> {
  final supabase = Supabase.instance.client;
  double? _totalIncome;
  double? _needs; // 50% of total income
  double? _wants; // 30% of total income
  double? _savings; // 20% of total income
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchTotalIncome();
  }

  Future<void> _fetchTotalIncome() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        throw Exception('You must be logged in to view savings suggestions.');
      }

      // Fetch total income from 'incomes' table
      final incomeResponse = await supabase
          .from('incomes')
          .select('amount')
          .eq('user_id', user.id);
      final incomes = (incomeResponse as List<dynamic>)
          .map((item) => (item['amount'] as num).toDouble())
          .toList();

      final transactionResponse = await supabase
          .from('transactions')
          .select('amount')
          .eq('user_id', user.id)
          .eq('type', 'Income');
      final transactionIncomes = (transactionResponse as List<dynamic>)
          .map((item) => (item['amount'] as num).toDouble())
          .toList();

      final totalIncome = (incomes + transactionIncomes)
          .fold<double>(0, (sum, amount) => sum + amount);

      setState(() {
        _totalIncome = totalIncome;
        _needs = totalIncome * 0.5; // 50% for Needs
        _wants = totalIncome * 0.3; // 30% for Wants
        _savings = totalIncome * 0.2; // 20% for Savings
        _isLoading = false;
        final allocations = _calculateAllocations(_savings!);
        allocations.forEach((key, value) {
        });
      });
    } catch (error) {
      setState(() {
        _errorMessage = 'Failed to fetch income: $error';
        _isLoading = false;
      });
    }
  }

  Map<String, double> _calculateAllocations(double savings) {
    return {
      'MIGA (30%)': savings * 0.3,
      'ASNB (20%)': savings * 0.2,
      'Wahed (20%)': savings * 0.2,
      'Keep for Trading (30%)': savings * 0.3, 
    };
  }

  final Map<String, Map<String, String>> _platforms = {
    'MIGA': {
      'image': 'images/maybank.png',
      'link': 'https://play.google.com/store/apps/details?id=com.maybank2u.life&hl=en&pli=1',
      'displayLink': 'Maybank App Link',
    },
    'ASNB': {
      'image': 'images/asnb.jpg',
      'link': 'https://play.google.com/store/apps/details?id=com.pnb.myASNBmobile&hl=en',
      'displayLink': 'ASNB App Link',
    },
    'Wahed': {
      'image': 'images/wahed.jpg',
      'link': 'https://play.google.com/store/apps/details?id=com.wahed.mobile&hl=en',
      'displayLink': 'Wahed App Link',
    },
  };

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not launch $url')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Savings Suggestions'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => FinanceApp()));
          },
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!, style: const TextStyle(fontSize: 18, color: Colors.red)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Your Total Income',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'RM${_totalIncome!.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 24, color: Colors.green),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Budget Allocation (50/30/20 Rule)',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Needs (50%)'),
                          Text('RM${_needs!.toStringAsFixed(2)}', style: const TextStyle(color: Colors.orange)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Wants (30%)'),
                          Text('RM${_wants!.toStringAsFixed(2)}', style: const TextStyle(color: Colors.purple)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Savings (20%)'),
                          Text('RM${_savings!.toStringAsFixed(2)}', style: const TextStyle(color: Colors.blue)),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Savings Allocation Suggestions',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Here’s how you could allocate your savings:',
                        style: TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 16),
                      ..._calculateAllocations(_savings!).entries.map((entry) {
                        final platformKey = entry.key.split(' ')[0];
                        if (platformKey == 'Keep') {
                          // Special case for "Keep in Cash"
                          return Card(
                            elevation: 2,
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                children: [
                                  const Icon(Icons.account_balance_wallet, size: 50, color: Colors.grey),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          entry.key,
                                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                        ),
                                        Text(
                                          'RM${entry.value.toStringAsFixed(2)}',
                                          style: const TextStyle(fontSize: 16),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        } else {
                          // Regular platform with image and link
                          final platform = _platforms[platformKey]!;
                          return Card(
                            elevation: 2,
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                children: [
                                  Image.asset(
                                    platform['image']!,
                                    width: 50,
                                    height: 50,
                                    errorBuilder: (context, error, stackTrace) =>
                                        const Icon(Icons.error, size: 50),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          entry.key,
                                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                        ),
                                        Text(
                                          'RM${entry.value.toStringAsFixed(2)}',
                                          style: const TextStyle(fontSize: 16),
                                        ),
                                        GestureDetector(
                                          onTap: () => _launchURL(platform['link']!),
                                          child: Text(
                                            platform['displayLink']!,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: Colors.blue,
                                              decoration: TextDecoration.underline,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                      }).toList(),
                      const SizedBox(height: 16),
                      const Text(
                        'Note: The remaining 30% of your savings can be kept as cash or allocated based on your goals in trading.',
                        style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ),
    );
  }
}