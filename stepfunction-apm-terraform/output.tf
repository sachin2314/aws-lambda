output "step_function_1_arn" {
  
  value = aws_sfn_state_machine.sf1.arn
}
output "step_function_2_arn" {
  value = aws_sfn_state_machine.sf2.arn
}
