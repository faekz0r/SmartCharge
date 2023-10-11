<html>
<head>
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0-beta3/css/all.min.css" integrity="sha384-k6Rqe9uvcReZ/lGO9sFHBcCs7Q6tSAa4wM4b0vyGp4F4cCMZF4W4x4S9g5fMHr7gZ9Fp" crossorigin="anonymous">
</head>
<body>

<div id="loadingIndicator" style="display:none;">
  <i class="fas fa-spinner fa-spin"></i> Loading...
</div>

<?php

$user_vars=fopen("/home/being/SmartCharge/php/user_vars.sh", "r");
$pattern='/^(\w+)="([\w\/\.\:]+)"/';
while ($line=fgets($user_vars, 80)) {

if (preg_match($pattern, $line, $match)) {
     $conf[$match[1]]=$match[2];
     }
}

# print_r($conf);

extract($conf);

echo '<span style="white-space: pre-line; line-height:30px">
<p>
  <form name="myForm" id="myForm" action="get_data.php" method="POST">
    Start hour: <input type="number" name="start_hour" min="0" max="23" value="'. $start_hour .'">
    End hour: <input type="number" name="end_hour" min="0" max="23" value="'. $end_hour .'">
    Charge for hours: <input type="number" name="charge_for_hours" min="0" max="23" value="'. $charge_for_hours. '">
    Max price (€/mWh): <input type="number" name="max_price_for_high_limit" value="'. $max_price_for_high_limit .'">
    Max charge limit %: <input type="number" name="max_charge_limit" min="50" max="100" value="'. $max_charge_limit .'">
    Min charge limit %: <input type="number" name="min_charge_limit" min="50" max="80" value="'. $min_charge_limit .'">
    <input type="submit" value="Save">
  </form>
</p>
</span>

<div id="postData"></div>


?>

<script src="https://code.jquery.com/jquery-3.6.0.min.js" integrity="sha256-/xUj+3OJU5yExlq6GSYGSHk7tPXikynS7ogEvDej/m4=" crossorigin="anonymous"></script>
<script src="functions.js"></script>
</body>
</html>
