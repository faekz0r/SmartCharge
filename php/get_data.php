<?php

$vars_in_json_array=json_encode($_POST);

echo json_encode($_POST);

// Prepare the jq command
$jq_to_bash = "jq -r 'to_entries | .[] | .key + \"=\" + (.value | @sh)' > vars";

// Execute the command
$command = "echo '$vars_in_json_array' | " . $jq_to_bash;
exec($command, $output, $return_var);

// Check for errors
if ($return_var !== 0) {
    // Handle the error appropriately
    die("An error occurred while executing the command.");
}

// Return a success response (you can customize this)
echo json_encode(['status' => 'success']);


?>
