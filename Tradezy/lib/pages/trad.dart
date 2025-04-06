import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:Tradezy/pages/portfolio.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:ui'; // For BackdropFilter

class LearnPage extends StatefulWidget {
  const LearnPage({super.key});

  @override
  _LearnPageState createState() => _LearnPageState();
}

class _LearnPageState extends State<LearnPage> {
  int _selectedIndex = 0;
  double virtualMoney = 10000.0;
  Map<String, List<FlSpot>> priceData = {
    'Bitcoin': [],
    'Gold': [],
    'Tesla': [],
    'Apple': [],
    'Maybank': [],
  };
  Map<String, Map<String, double>> investments = {
    'Bitcoin': {'quantity': 0.0, 'purchasePrice': 0.0},
    'Gold': {'quantity': 0.0, 'purchasePrice': 0.0},
    'Tesla': {'quantity': 0.0, 'purchasePrice': 0.0},
    'Apple': {'quantity': 0.0, 'purchasePrice': 0.0},
    'Maybank': {'quantity': 0.0, 'purchasePrice': 0.0},
  };
  String selectedAsset = 'Bitcoin';
  String selectedTimePeriod = '1D';
  bool _isLoading = true;
  String? _errorMessage;
  double usdToMyrRate = 4.3;
  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    fetchExchangeRate().then((_) => fetchPriceData());
    _loadInitialVirtualMoney();
  }

  Future<void> _loadInitialVirtualMoney() async {
    if (supabase.auth.currentUser == null) {
      setState(() {
        _errorMessage = 'User not authenticated';
      });
      return;
    }
    try {
      final response = await supabase
          .from('profiles')
          .select('virtual_money')
          .eq('id', supabase.auth.currentUser!.id)
          .single();
      final dbVirtualMoney = (response['virtual_money'] as num?)?.toDouble() ?? 10000.0;
      setState(() {
        virtualMoney = dbVirtualMoney;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load virtual money: $e';
      });
    }
  }

  Future<void> fetchExchangeRate() async {
    try {
      final response = await http.get(Uri.parse('https://api.exchangerate-api.com/v4/latest/USD'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          usdToMyrRate = data['rates']['MYR'].toDouble();
        });
      } else {
        throw Exception('Failed to fetch exchange rate');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error fetching exchange rate: $e';
        usdToMyrRate = 4.3;
      });
    }
  }

  Future<void> fetchPriceData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final bitcoinData = await fetchBitcoinPriceData(selectedTimePeriod);
      setState(() {
        priceData['Bitcoin'] = bitcoinData;
      });

      setState(() {
        priceData['Gold'] = [
          FlSpot(0, 2600 * usdToMyrRate),
          FlSpot(1, 2620 * usdToMyrRate),
          FlSpot(2, 2590 * usdToMyrRate),
          FlSpot(3, 2630 * usdToMyrRate),
          FlSpot(4, 2610 * usdToMyrRate),
        ];
        priceData['Tesla'] = [
          FlSpot(0, 350 * usdToMyrRate),
          FlSpot(1, 355 * usdToMyrRate),
          FlSpot(2, 340 * usdToMyrRate),
          FlSpot(3, 360 * usdToMyrRate),
          FlSpot(4, 365 * usdToMyrRate),
        ];
        priceData['Apple'] = [
          FlSpot(0, 250 * usdToMyrRate),
          FlSpot(1, 253 * usdToMyrRate),
          FlSpot(2, 247 * usdToMyrRate),
          FlSpot(3, 255 * usdToMyrRate),
          FlSpot(4, 257 * usdToMyrRate),
        ];
        priceData['Maybank'] = [
          FlSpot(0, 10.50),
          FlSpot(1, 10.60),
          FlSpot(2, 10.40),
          FlSpot(3, 10.70),
          FlSpot(4, 10.55),
        ];
      });

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        priceData['Bitcoin'] = [
          FlSpot(0, 84500 * usdToMyrRate),
          FlSpot(1, 84600 * usdToMyrRate),
          FlSpot(2, 84300 * usdToMyrRate),
          FlSpot(3, 84800 * usdToMyrRate),
          FlSpot(4, 84500 * usdToMyrRate),
        ];
        _errorMessage = 'Failed to fetch price data: $e. Using fallback data.';
        _isLoading = false;
      });
    }
  }

  Future<List<FlSpot>> fetchBitcoinPriceData(String timePeriod) async {
    String url;
    int intervalMinutes;
    switch (timePeriod) {
      case '1D':
        url = 'https://api.coingecko.com/api/v3/coins/bitcoin/market_chart?vs_currency=usd&days=1';
        intervalMinutes = 60;
        break;
      case '1W':
        url = 'https://api.coingecko.com/api/v3/coins/bitcoin/market_chart?vs_currency=usd&days=7';
        intervalMinutes = 240;
        break;
      case '1M':
      default:
        url = 'https://api.coingecko.com/api/v3/coins/bitcoin/market_chart?vs_currency=usd&days=30';
        intervalMinutes = 1440;
        break;
    }

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final prices = data['prices'] as List;
      final filteredPrices = prices.asMap().entries.where((entry) => entry.key % (intervalMinutes ~/ 60) == 0).toList();
      return filteredPrices.map((entry) {
        final priceInUsd = (entry.value[1] as num).toDouble();
        final priceInMyr = priceInUsd * usdToMyrRate;
        return FlSpot(entry.key.toDouble(), priceInMyr);
      }).toList();
    } else {
      throw Exception('Failed to fetch Bitcoin price data');
    }
  }

  Future<void> _updateVirtualMoney(double newMoney) async {
    if (supabase.auth.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not authenticated')),
      );
      return;
    }
    try {
      await supabase
          .from('profiles')
          .update({'virtual_money': newMoney})
          .eq('id', supabase.auth.currentUser!.id);
      setState(() {
        virtualMoney = newMoney;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Virtual money updated to RM ${newMoney.toStringAsFixed(2)}'),
          backgroundColor: const Color(0xFF007BFF),
        ),
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to update virtual money: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update virtual money: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _onMoneyUpdate(double newMoney) {
    setState(() {
      virtualMoney = newMoney;
    });
  }

  void _onInvestmentsUpdate(Map<String, Map<String, double>> newInvestments) {
    setState(() {
      investments = newInvestments;
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      if (index == 1) {
        fetchPriceData();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> _pages = [
      const HowTradingWorksPage(),
      SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildVirtualMoneyCard(),
              const SizedBox(height: 20),
              _buildPriceTrendsCard(),
            ],
          ),
        ),
      ),
      PortfolioPage(
        virtualMoney: virtualMoney,
        priceData: priceData,
        investments: investments,
        selectedTimePeriod: selectedTimePeriod,
        onMoneyUpdate: _onMoneyUpdate,
        onInvestmentsUpdate: _onInvestmentsUpdate,
        onFetchPriceData: fetchPriceData,
      ),
      const BestTradingPlatformsPage(),
    ];

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Trading Academy',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
          ),
        ),
        elevation: 0,
      ),
      backgroundColor: Colors.white,
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(Icons.book_outlined),
              activeIcon: Icon(Icons.book),
              label: 'Learn',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.trending_up_outlined),
              activeIcon: Icon(Icons.trending_up),
              label: 'Trends',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_wallet_outlined),
              activeIcon: Icon(Icons.account_balance_wallet),
              label: 'Portfolio',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.business_center_outlined),
              activeIcon: Icon(Icons.business_center),
              label: 'Platforms',
            ),
          ],
          currentIndex: _selectedIndex,
          selectedItemColor: const Color(0xFF007BFF),
          unselectedItemColor: Colors.grey,
          backgroundColor: Colors.white,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
          elevation: 0,
          onTap: _onItemTapped,
        ),
      ),
    );
  }

  Widget _buildVirtualMoneyCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [Color(0xFF007BFF), Color(0xFF4DA3FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Virtual Trading Balance',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'RM ${virtualMoney.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
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
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        virtualMoney += 5000.0;
                      });
                      _updateVirtualMoney(virtualMoney);
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add RM 5,000'),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: const Color(0xFF007BFF),
                      backgroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        virtualMoney = 10000.0;
                      });
                      _updateVirtualMoney(10000.0);
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reset'),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: const Color(0xFF007BFF),
                      backgroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
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

  Widget _buildPriceTrendsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Price Trends',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3436),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Color(0xFF007BFF)),
                  onPressed: fetchPriceData,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildAssetDropdown(),
                _buildTimeframeDropdown(),
              ],
            ),
            const SizedBox(height: 20),
            _isLoading
                ? const Center(
              child: Column(
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF007BFF)),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Loading price data...',
                    style: TextStyle(
                      color: Color(0xFF2D3436),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
                : _errorMessage != null
                ? Center(
              child: Column(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: fetchPriceData,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF007BFF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
                : priceData[selectedAsset]!.isEmpty
                ? Center(
              child: Column(
                children: [
                  Icon(
                    Icons.bar_chart_outlined,
                    color: Colors.grey[400],
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No data available for this asset.',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
                : Container(
              height: 400,
              padding: const EdgeInsets.only(top: 16),
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: _getFixedYInterval(selectedAsset),
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.grey[300]!,
                        strokeWidth: 1,
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 60,
                        interval: _getFixedYInterval(selectedAsset),
                        getTitlesWidget: (value, meta) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: Text(
                              _formatPrice(value, selectedAsset),
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: const AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: false,
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: false,
                      ),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: false,
                      ),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border(
                      bottom: BorderSide(color: Colors.grey[300]!, width: 1),
                      left: BorderSide(color: Colors.grey[300]!, width: 1),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: priceData[selectedAsset]!,
                      isCurved: true,
                      color: const Color(0xFF007BFF),
                      barWidth: 3,
                      dotData: FlDotData(
                        show: false,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 4,
                            color: const Color(0xFF007BFF),
                            strokeWidth: 2,
                            strokeColor: Colors.white,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: const Color(0xFF007BFF).withOpacity(0.1),
                      ),
                    ),
                  ],
                  minY: _getMinY(selectedAsset) != null ? _getMinY(selectedAsset)! * 0.7 : null,
                  maxY: _getMaxY(selectedAsset) != null ? _getMaxY(selectedAsset)! * 1.3 : null,
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (!_isLoading && _errorMessage == null && priceData[selectedAsset]!.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF007BFF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: Color(0xFF007BFF),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This chart shows the price trend for $selectedAsset over the last $selectedTimePeriod. Use this data to make informed trading decisions.',
                        style: const TextStyle(
                          color: Color(0xFF007BFF),
                          fontSize: 14,
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

  Widget _buildAssetDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButton<String>(
        value: selectedAsset,
        underline: const SizedBox(),
        icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF007BFF)),
        style: const TextStyle(
          color: Color(0xFF2D3436),
          fontSize: 16,
        ),
        items: ['Bitcoin', 'Gold', 'Tesla', 'Apple', 'Maybank'].map((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(value),
          );
        }).toList(),
        onChanged: (String? newValue) {
          setState(() {
            selectedAsset = newValue!;
          });
        },
      ),
    );
  }

  Widget _buildTimeframeDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButton<String>(
        value: selectedTimePeriod,
        underline: const SizedBox(),
        icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF007BFF)),
        style: const TextStyle(
          color: Color(0xFF2D3436),
          fontSize: 16,
        ),
        items: ['1D', '1W', '1M'].map((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(value),
          );
        }).toList(),
        onChanged: (String? newValue) {
          setState(() {
            selectedTimePeriod = newValue!;
            fetchPriceData();
          });
        },
      ),
    );
  }

  double _getFixedYInterval(String asset) {
    switch (asset) {
      case 'Bitcoin':
        return 50000.0;
      case 'Gold':
        return 10000.0;
      case 'Tesla':
        return 5000.0;
      case 'Apple':
        return 5000.0;
      case 'Maybank':
        return 2.0;
      default:
        return 10000.0;
    }
  }

  double? _getMinY(String asset) {
    final data = priceData[asset];
    if (data == null || data.isEmpty) return null;
    return data.map((spot) => spot.y).reduce((a, b) => a < b ? a : b);
  }

  double? _getMaxY(String asset) {
    final data = priceData[asset];
    if (data == null || data.isEmpty) return null;
    return data.map((spot) => spot.y).reduce((a, b) => a > b ? a : b);
  }

  String _formatPrice(double value, String asset) {
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)}k';
    } else if (asset == 'Maybank') {
      return value.toStringAsFixed(2);
    } else {
      return value.toStringAsFixed(0);
    }
  }
}

class HowTradingWorksPage extends StatelessWidget {
  const HowTradingWorksPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF007BFF), Color(0xFF4DA3FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16.0),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF007BFF).withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Understanding Trading Basics',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'Master the art of trading financial assets like stocks, cryptocurrencies, and commodities to profit from price movements.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.0),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.show_chart, color: Color(0xFF007BFF), size: 28),
                      SizedBox(width: 12),
                      Text(
                        'Key Trading Concepts',
                        style: TextStyle(
                          color: Color(0xFF2D3436),
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildEnhancedBulletPoint(
                    icon: Icons.trending_up,
                    text: 'Buy and Sell: Buy low, sell high to make a profit. Alternatively, use short-selling to profit from falling prices.',
                  ),
                  _buildEnhancedBulletPoint(
                    icon: Icons.swap_horiz,
                    text: 'Long and Short Positions: Go long if you expect prices to rise, or short if you anticipate a decline.',
                  ),
                  _buildEnhancedBulletPoint(
                    icon: Icons.attach_money,
                    text: 'Leverage: Borrow funds to amplify your position, boosting both potential gains and losses.',
                  ),
                  _buildEnhancedBulletPoint(
                    icon: Icons.shield,
                    text: 'Risk Management: Use stop-loss orders and invest only what you can afford to lose.',
                  ),
                  _buildEnhancedBulletPoint(
                    icon: Icons.bar_chart,
                    text: 'Technical Analysis: Analyze price charts and indicators (e.g., Moving Averages, RSI) for predictions.',
                  ),
                  _buildEnhancedBulletPoint(
                      icon: Icons.trending_up_outlined,
                      text: 'Fundamental Analysis: Assess an assets value using economic data, earnings, and market trends.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.0),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.play_arrow, color: Color(0xFF007BFF), size: 28),
                      SizedBox(width: 12),
                      Text(
                        'Getting Started',
                        style: TextStyle(
                          color: Color(0xFF2D3436),
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Follow these steps to begin your trading journey:',
                    style: TextStyle(
                      color: Color(0xFF2D3436),
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildStep('1. Choose a platform (explore Best Trading Platforms).'),
                  _buildStep('2. Practice with a demo account to build confidence.'),
                  _buildStep('3. Create a trading plan with clear goals and risk limits.'),
                  _buildStep('4. Start with small investments and scale up with experience.'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Quiz Section
          const TradingQuizSection(),
        ],
      ),
    );
  }

  Widget _buildEnhancedBulletPoint({required IconData icon, required String text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF007BFF).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFF007BFF), size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF2D3436),
                fontSize: 16,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF007BFF).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.check_circle,
              color: Color(0xFF007BFF),
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF2D3436),
                fontSize: 16,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TradingQuizSection extends StatefulWidget {
  const TradingQuizSection({super.key});

  @override
  State<TradingQuizSection> createState() => _TradingQuizSectionState();
}

class _TradingQuizSectionState extends State<TradingQuizSection> {
  final List<Map<String, dynamic>> quizQuestions = [
    {
      'question': 'What does it mean to "go long" in trading?',
      'options': [
        'A) Selling an asset to profit from a price drop',
        'B) Buying an asset expecting its price to rise',
        'C) Holding an asset for a short period',
        'D) Using leverage to amplify losses'
      ],
      'correctAnswer': 1,
    },
    {
      'question': 'What is the purpose of a stop-loss order?',
      'options': [
        'A) To automatically buy an asset at a lower price',
        'B) To limit potential losses by selling an asset at a predetermined price',
        'C) To increase leverage on a position',
        'D) To analyze price charts'
      ],
      'correctAnswer': 1,
    },
    {
      'question': 'What does leverage allow traders to do?',
      'options': [
        'A) Trade without any risk',
        'B) Borrow funds to increase the size of their position',
        'C) Avoid paying taxes on profits',
        'D) Automatically close losing trades'
      ],
      'correctAnswer': 1,
    },
    {
      'question': 'What is technical analysis primarily based on?',
      'options': [
        'A) Economic data and company earnings',
        'B) Price charts and trading indicators',
        'C) News headlines and rumors',
        'D) Government policies'
      ],
      'correctAnswer': 1,
    },
    {
      'question': 'What should you do first before starting to trade with real money?',
      'options': [
        'A) Practice with a demo account',
        'B) Invest all your savings',
        'C) Use maximum leverage',
        'D) Ignore risk management'
      ],
      'correctAnswer': 0,
    },
  ];

  List<int?> userAnswers = List.filled(5, null); // Track user's selected answers
  bool isSubmitted = false;
  int score = 0;

  void _submitQuiz() {
    setState(() {
      isSubmitted = true;
      score = 0;
      for (int i = 0; i < quizQuestions.length; i++) {
        if (userAnswers[i] == quizQuestions[i]['correctAnswer']) {
          score++;
        }
      }
    });
  }

  void _resetQuiz() {
    setState(() {
      userAnswers = List.filled(5, null);
      isSubmitted = false;
      score = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Container(
        padding: const EdgeInsets.all(20.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.0),
          border: Border.all(
            color: const Color(0xFF007BFF).withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF007BFF).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.quiz,
                    color: Color(0xFF007BFF),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                const Text(
                  'Test Your Knowledge',
                  style: TextStyle(
                    color: Color(0xFF2D3436),
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Answer the following questions to test your understanding of trading basics:',
              style: TextStyle(
                color: Color(0xFF2D3436),
                fontSize: 16,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            ...List.generate(quizQuestions.length, (index) {
              return _buildQuizQuestion(index);
            }),
            const SizedBox(height: 24),
            if (isSubmitted)
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: score > 3
                          ? Colors.green.withOpacity(0.1)
                          : const Color(0xFF007BFF).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          score > 3 ? Icons.emoji_events : Icons.school,
                          color: score > 3 ? Colors.green : const Color(0xFF007BFF),
                          size: 28,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Your Score: $score/${quizQuestions.length}',
                                style: TextStyle(
                                  color: score > 3 ? Colors.green : const Color(0xFF007BFF),
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                score > 3
                                    ? 'Great job! You have a solid understanding of trading basics.'
                                    : 'Keep learning! Review the concepts and try again.',
                                style: TextStyle(
                                  color: score > 3 ? Colors.green[700] : const Color(0xFF007BFF),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _resetQuiz,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try Again'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF007BFF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              )
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _submitQuiz,
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Check Answers'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF007BFF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuizQuestion(int index) {
    final question = quizQuestions[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSubmitted && userAnswers[index] != null
              ? userAnswers[index] == question['correctAnswer']
              ? Colors.green.withOpacity(0.3)
              : Colors.red.withOpacity(0.3)
              : Colors.grey[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF007BFF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: Color(0xFF007BFF),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  question['question'],
                  style: const TextStyle(
                    color: Color(0xFF2D3436),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...List.generate(question['options'].length, (optionIndex) {
            final isCorrect = optionIndex == question['correctAnswer'];
            final isSelected = userAnswers[index] == optionIndex;
            final showCorrectness = isSubmitted && (isCorrect || isSelected);

            return InkWell(
              onTap: isSubmitted ? null : () {
                setState(() {
                  userAnswers[index] = optionIndex;
                });
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: showCorrectness
                      ? isCorrect
                      ? Colors.green.withOpacity(0.1)
                      : Colors.red.withOpacity(0.1)
                      : isSelected
                      ? const Color(0xFF007BFF).withOpacity(0.1)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: showCorrectness
                        ? isCorrect
                        ? Colors.green
                        : Colors.red
                        : isSelected
                        ? const Color(0xFF007BFF)
                        : Colors.grey[300]!,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      showCorrectness
                          ? isCorrect
                          ? Icons.check_circle
                          : Icons.cancel
                          : isSelected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: showCorrectness
                          ? isCorrect
                          ? Colors.green
                          : Colors.red
                          : isSelected
                          ? const Color(0xFF007BFF)
                          : Colors.grey[400],
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        question['options'][optionIndex],
                        style: TextStyle(
                          color: showCorrectness
                              ? isCorrect
                              ? Colors.green[700]
                              : Colors.red[700]
                              : isSelected
                              ? const Color(0xFF007BFF)
                              : const Color(0xFF2D3436),
                          fontWeight: isSelected || (showCorrectness && isCorrect)
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class BestTradingPlatformsPage extends StatefulWidget {
  const BestTradingPlatformsPage({super.key});

  @override
  _BestTradingPlatformsPageState createState() => _BestTradingPlatformsPageState();
}

class _BestTradingPlatformsPageState extends State<BestTradingPlatformsPage> {
  String selectedCategory = 'Beginner';
  bool _isLaunchingUrl = false;

  final Map<String, List<Map<String, String>>> platforms = {
    'Beginner': [
      {
        'title': 'Moomoo',
        'pros': 'Commission-free stocks, powerful analytical tools, paper trading feature.',
        'cons': 'Limited crypto support, learning curve for beginners.',
        'image': 'images/moomoo.png',
        'link': 'https://play.google.com/store/apps/details?id=com.moomoo.trade&hl=en'
      },
      {
        'title': 'Luno',
        'pros': 'User-friendly, good for cryptocurrency trading, regulated.',
        'cons': 'Limited trading pairs, higher fees.',
        'image': 'images/luno.jpeg',
        'link': 'https://play.google.com/store/apps/details?id=co.bitx.android.wallet&hl=en'
      },
    ],
    'Amateur': [
      {
        'title': 'XM',
        'pros': 'Regulated broker, multiple trading instruments, good customer support.',
        'cons': 'Moderate risk, higher fees on some accounts.',
        'image': 'images/xm.png',
        'link': 'https://play.google.com/store/apps/details?id=com.xm.webapp&hl=en'
      },
      {
        'title': 'FBS',
        'pros': 'High leverage, fast execution, cashback program.',
        'cons': 'High risk, withdrawal limitations.',
        'image': 'images/fbs.png',
        'link': 'https://play.google.com/store/apps/details?id=com.fbs.pa&hl=en'
      },
    ],
    'Pro': [
      {
        'title': 'ExpertOption',
        'pros': 'Easy to use, good for short-term trading, social trading features.',
        'cons': 'High risk, limited assets, not available in some regions.',
        'image': 'images/eo.jpeg',
        'link': 'https://play.google.com/store/apps/details?id=com.expertoption&hl=en'
      },
      {
        'title': 'Octa Trading',
        'pros': 'Low spreads, multiple account types, high leverage.',
        'cons': 'High risk, strict regulations in some countries.',
        'image': 'images/octa.png',
        'link': 'https://play.google.com/store/apps/details?id=com.octafx&hl=en'
      },
    ],
  };

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20.0),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF007BFF), Color(0xFF4DA3FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16.0),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF007BFF).withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Top Trading Platforms for 2025',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Find the best platform for your trading level and start your journey today.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButton<String>(
                      value: selectedCategory,
                      underline: const SizedBox(),
                      isExpanded: true,
                      icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF007BFF)),
                      style: const TextStyle(
                        color: Color(0xFF2D3436),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      onChanged: (String? newValue) {
                        setState(() {
                          selectedCategory = newValue!;
                        });
                      },
                      items: ['Beginner', 'Amateur', 'Pro'].map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ...platforms[selectedCategory]!.map((platform) => _buildPlatformCard(
              title: platform['title']!,
              pros: platform['pros']!,
              cons: platform['cons']!,
              image: platform['image']!,
              link: platform['link']!,
            )).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildPlatformCard({
    required String title,
    required String pros,
    required String cons,
    required String image,
    required String link,
  }) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      image,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: const Color(0xFF007BFF).withOpacity(0.1),
                          child: const Icon(
                            Icons.business,
                            color: Color(0xFF007BFF),
                            size: 30,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Color(0xFF2D3436),
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF007BFF).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Recommended for $selectedCategory Traders',
                          style: const TextStyle(
                            color: Color(0xFF007BFF),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildFeatureSection('Pros', pros, Icons.thumb_up, Colors.green),
            const SizedBox(height: 12),
            _buildFeatureSection('Cons', cons, Icons.thumb_down, Colors.red),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLaunchingUrl
                    ? null
                    : () async {
                  setState(() {
                    _isLaunchingUrl = true;
                  });
                  await _launchURL(link);
                  setState(() {
                    _isLaunchingUrl = false;
                  });
                },
                icon: _isLaunchingUrl
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : const Icon(Icons.download),
                label: const Text('Install App'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF007BFF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureSection(String title, String content, IconData icon, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: color,
            size: 20,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                content,
                style: const TextStyle(
                  color: Color(0xFF2D3436),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _launchURL(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not launch URL'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error launching URL: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

