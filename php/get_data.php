<?php

// Validate and sanitize input (this is a simplified example; you should expand on this)
$validated_post_data = [];
foreach ($_POST as $key => $value) {
    // Add your validation logic here
    $validated_post_data[$key] = escapeshellarg($value);
}

// Convert to JSON
$vars_in_json_array = json_encode($validated_post_data);

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
